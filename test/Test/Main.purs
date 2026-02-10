module Test.Main where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..), isNothing)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Effect.Exception (throw)
import Solid.Context as Context
import Solid.Lifecycle (onCleanup, onMount)
import Solid.Reactivity (createComputed, createEffect, createMemo, createReaction, createRenderEffect, createSelector)
import Solid.Resource as Resource
import Solid.Root (createRoot)
import Solid.Signal (Equality(..), createSignal, createSignalWith, defaultSignalOptions, get, modify, set)
import Solid.Store as Store
import Solid.Utility (batch, defaultOnOptions, getOwner, on, onWith, runWithOwner, untrack)
import Solid.Web as Web
import Type.Proxy (Proxy(..))

assertEqual :: forall a. Eq a => Show a => String -> a -> a -> Effect Unit
assertEqual label expected actual =
  if expected == actual then
    pure unit
  else
    throw (label <> ": expected " <> show expected <> ", got " <> show actual)

expectRight :: forall l r. Show l => String -> Either l r -> Effect r
expectRight label result =
  case result of
    Left leftValue ->
      throw (label <> ": unexpected Left " <> show leftValue)
    Right rightValue ->
      pure rightValue

foreign import sameRef :: forall a. a -> a -> Boolean

foreign import serverMountStub :: Web.Mountable

main :: Effect Unit
main = do
  log "Signal tests starting"

  createRoot \dispose -> do
    count /\ setCount <- createSignal 0
    initialCount <- get count
    assertEqual "initial count" 0 initialCount

    _ <- set setCount 5
    updatedCount <- get count
    assertEqual "set count" 5 updatedCount

    _ <- modify setCount (_ + 2)
    modifiedCount <- get count
    assertEqual "modify count" 7 modifiedCount

    doubled <- createMemo do
      currentCount <- get count
      pure (currentCount * 2)

    initialDoubled <- get doubled
    assertEqual "createMemo initial value" 14 initialDoubled

    _ <- set setCount 9
    updatedDoubled <- get doubled
    assertEqual "createMemo updated value" 18 updatedDoubled

    fnSignal /\ setFnSignal <- createSignal (\_ -> 1)
    _ <- set setFnSignal (\_ -> 42)
    fn <- get fnSignal
    assertEqual "function-valued signal" 42 (fn unit)

    ticks /\ setTicks <- createSignalWith
      (defaultSignalOptions { equality = AlwaysNotify, name = "ticks" })
      0
    _ <- set setTicks 1
    ticksValue <- get ticks
    assertEqual "createSignalWith value" 1 ticksValue

    dispose

  log "Signal tests passed"

  log "Utility tests starting"

  batchFixture <- createRoot \dispose -> do
    left /\ setLeft <- createSignal 0
    right /\ setRight <- createSignal 0
    runs /\ setRuns <- createSignal 0

    _ <- createEffect do
      _ <- get left
      _ <- get right
      _ <- modify setRuns (_ + 1)
      pure unit

    pure
      { setLeft
      , setRight
      , runs
      , dispose
      }

  baselineRuns <- get batchFixture.runs

  _ <- set batchFixture.setLeft 1
  _ <- set batchFixture.setRight 1

  afterUnbatchedRuns <- get batchFixture.runs
  assertEqual
    "unbatched updates run downstream effect twice"
    (baselineRuns + 2)
    afterUnbatchedRuns

  _ <- batch do
    _ <- set batchFixture.setLeft 2
    _ <- set batchFixture.setRight 2
    pure unit

  afterBatchedRuns <- get batchFixture.runs
  assertEqual
    "batched updates run downstream effect once"
    (afterUnbatchedRuns + 1)
    afterBatchedRuns

  batchFixture.dispose

  utilityFixture <- createRoot \dispose -> do
    source /\ setSource <- createSignal 10
    immediateRuns /\ setImmediateRuns <- createSignal 0
    deferredRuns /\ setDeferredRuns <- createSignal 0
    deferredPrev /\ setDeferredPrev <- createSignal (-1)
    untrackedRuns /\ setUntrackedRuns <- createSignal 0

    _ <- createEffect $ on source \_ _ -> do
      _ <- modify setImmediateRuns (_ + 1)
      pure unit

    _ <- createEffect $ onWith (defaultOnOptions { defer = true }) source \_ previous -> do
      _ <- modify setDeferredRuns (_ + 1)
      case previous of
        Just prev -> do
          _ <- set setDeferredPrev prev
          pure unit
        Nothing ->
          pure unit

    _ <- createEffect do
      _ <- untrack (get source)
      _ <- modify setUntrackedRuns (_ + 1)
      pure unit

    pure
      { setSource
      , immediateRuns
      , deferredRuns
      , deferredPrev
      , untrackedRuns
      , dispose
      }

  initialImmediateRuns <- get utilityFixture.immediateRuns
  assertEqual "on runs immediately by default" 1 initialImmediateRuns

  initialDeferredRuns <- get utilityFixture.deferredRuns
  assertEqual "onWith defer skips initial execution" 0 initialDeferredRuns

  initialUntrackedRuns <- get utilityFixture.untrackedRuns
  assertEqual "untrack effect runs once initially" 1 initialUntrackedRuns

  _ <- set utilityFixture.setSource 20

  updatedImmediateRuns <- get utilityFixture.immediateRuns
  assertEqual "on reacts to dependency changes" 2 updatedImmediateRuns

  updatedDeferredRuns <- get utilityFixture.deferredRuns
  assertEqual "deferred on runs on first dependency change" 1 updatedDeferredRuns

  deferredPreviousValue <- get utilityFixture.deferredPrev
  assertEqual "deferred on receives previous dependency value" 10 deferredPreviousValue

  updatedUntrackedRuns <- get utilityFixture.untrackedRuns
  assertEqual "untrack reads do not subscribe" 1 updatedUntrackedRuns

  utilityFixture.dispose

  log "Lifecycle tests starting"

  ownerOutside <- getOwner
  case ownerOutside of
    Just _ ->
      throw "getOwner outside reactive context should return Nothing"
    Nothing ->
      pure unit

  lifecycleFixture <- createRoot \dispose -> do
    mountRuns /\ setMountRuns <- createSignal 0
    cleanupRuns /\ setCleanupRuns <- createSignal 0
    transferredCleanupRuns /\ setTransferredCleanupRuns <- createSignal 0

    _ <- onMount do
      _ <- modify setMountRuns (_ + 1)
      pure unit

    _ <- onCleanup do
      _ <- modify setCleanupRuns (_ + 1)
      pure unit

    owner <- getOwner

    pure
      { mountRuns
      , cleanupRuns
      , transferredCleanupRuns
      , setTransferredCleanupRuns
      , owner
      , dispose
      }

  mountedRuns <- get lifecycleFixture.mountRuns
  assertEqual "onMount executes once after initial setup" 1 mountedRuns

  case lifecycleFixture.owner of
    Nothing ->
      throw "getOwner inside createRoot should return Just"
    Just owner -> do
      _ <- runWithOwner owner do
        _ <- onCleanup do
          _ <- modify lifecycleFixture.setTransferredCleanupRuns (_ + 1)
          pure unit
        pure unit

      cleanupBeforeDispose <- get lifecycleFixture.cleanupRuns
      assertEqual "onCleanup not run before disposal" 0 cleanupBeforeDispose

      transferredBeforeDispose <- get lifecycleFixture.transferredCleanupRuns
      assertEqual "transferred cleanup not run before disposal" 0 transferredBeforeDispose

      lifecycleFixture.dispose

      cleanupAfterDispose <- get lifecycleFixture.cleanupRuns
      assertEqual "onCleanup runs on root disposal" 1 cleanupAfterDispose

      transferredAfterDispose <- get lifecycleFixture.transferredCleanupRuns
      assertEqual "runWithOwner transfers owner for cleanup registration" 1 transferredAfterDispose

  log "Secondary primitive tests starting"

  timingFixture <- createRoot \dispose -> do
    source /\ setSource <- createSignal 0
    computedRuns /\ setComputedRuns <- createSignal 0
    renderRuns /\ setRenderRuns <- createSignal 0
    effectRuns /\ setEffectRuns <- createSignal 0

    _ <- createComputed do
      _ <- get source
      _ <- modify setComputedRuns (_ + 1)
      pure unit

    _ <- createRenderEffect do
      _ <- get source
      _ <- modify setRenderRuns (_ + 1)
      pure unit

    _ <- createEffect do
      _ <- get source
      _ <- modify setEffectRuns (_ + 1)
      pure unit

    _ <- set setSource 1
    _ <- set setSource 2

    pure
      { setSource
      , computedRuns
      , renderRuns
      , effectRuns
      , dispose
      }

  computedAfterSetup <- get timingFixture.computedRuns
  assertEqual "createComputed runs for each synchronous update" 3 computedAfterSetup

  renderAfterSetup <- get timingFixture.renderRuns
  assertEqual "createRenderEffect batches updates during setup" 2 renderAfterSetup

  effectAfterSetup <- get timingFixture.effectRuns
  assertEqual "createEffect initial run happens after setup updates" 1 effectAfterSetup

  _ <- set timingFixture.setSource 3

  computedAfterUpdate <- get timingFixture.computedRuns
  assertEqual "createComputed reacts to later updates" 4 computedAfterUpdate

  renderAfterUpdate <- get timingFixture.renderRuns
  assertEqual "createRenderEffect reacts to later updates" 3 renderAfterUpdate

  effectAfterUpdate <- get timingFixture.effectRuns
  assertEqual "createEffect reacts to later updates" 2 effectAfterUpdate

  timingFixture.dispose

  reactionFixture <- createRoot \dispose -> do
    source /\ setSource <- createSignal 0
    invalidations /\ setInvalidations <- createSignal 0

    track <- createReaction do
      _ <- modify setInvalidations (_ + 1)
      pure unit

    _ <- track do
      _ <- get source
      pure unit

    pure
      { source
      , setSource
      , invalidations
      , track
      , dispose
      }

  reactionInitialInvalidations <- get reactionFixture.invalidations
  assertEqual "createReaction does not invalidate before dependency changes" 0 reactionInitialInvalidations

  _ <- set reactionFixture.setSource 1

  reactionAfterFirstSet <- get reactionFixture.invalidations
  assertEqual "createReaction invalidates on first dependency change" 1 reactionAfterFirstSet

  _ <- set reactionFixture.setSource 2

  reactionAfterSecondSet <- get reactionFixture.invalidations
  assertEqual "createReaction invalidates once until retracked" 1 reactionAfterSecondSet

  _ <- reactionFixture.track do
    _ <- get reactionFixture.source
    pure unit

  _ <- set reactionFixture.setSource 3

  reactionAfterRetrack <- get reactionFixture.invalidations
  assertEqual "createReaction invalidates again after retracking" 2 reactionAfterRetrack

  reactionFixture.dispose

  selectorFixture <- createRoot \dispose -> do
    selected /\ setSelected <- createSignal 1
    isSelected <- createSelector selected
    row1Runs /\ setRow1Runs <- createSignal 0
    row2Runs /\ setRow2Runs <- createSignal 0
    row3Runs /\ setRow3Runs <- createSignal 0

    _ <- createEffect do
      _ <- isSelected 1
      _ <- modify setRow1Runs (_ + 1)
      pure unit

    _ <- createEffect do
      _ <- isSelected 2
      _ <- modify setRow2Runs (_ + 1)
      pure unit

    _ <- createEffect do
      _ <- isSelected 3
      _ <- modify setRow3Runs (_ + 1)
      pure unit

    pure
      { isSelected
      , setSelected
      , row1Runs
      , row2Runs
      , row3Runs
      , dispose
      }

  selectorInitialRow1 <- get selectorFixture.row1Runs
  assertEqual "selector row 1 initial run" 1 selectorInitialRow1

  selectorInitialRow2 <- get selectorFixture.row2Runs
  assertEqual "selector row 2 initial run" 1 selectorInitialRow2

  selectorInitialRow3 <- get selectorFixture.row3Runs
  assertEqual "selector row 3 initial run" 1 selectorInitialRow3

  _ <- set selectorFixture.setSelected 2

  selectorAfter2Row1 <- get selectorFixture.row1Runs
  assertEqual "selector updates row 1 when value toggles" 2 selectorAfter2Row1

  selectorAfter2Row2 <- get selectorFixture.row2Runs
  assertEqual "selector updates row 2 when value toggles" 2 selectorAfter2Row2

  selectorAfter2Row3 <- get selectorFixture.row3Runs
  assertEqual "selector skips unaffected row 3" 1 selectorAfter2Row3

  _ <- set selectorFixture.setSelected 3

  selectorAfter3Row1 <- get selectorFixture.row1Runs
  assertEqual "selector keeps row 1 stable when still false" 2 selectorAfter3Row1

  selectorAfter3Row2 <- get selectorFixture.row2Runs
  assertEqual "selector updates row 2 when toggling false" 3 selectorAfter3Row2

  selectorAfter3Row3 <- get selectorFixture.row3Runs
  assertEqual "selector updates row 3 when toggling true" 2 selectorAfter3Row3

  is3Selected <- selectorFixture.isSelected 3
  assertEqual "selector reports current selected key" true is3Selected

  selectorFixture.dispose

  log "Resource tests starting"

  sourcedResourceFixture <- createRoot \dispose -> do
    source /\ setSource <- createSignal (Nothing :: Maybe Int)
    fetchRuns /\ setFetchRuns <- createSignal 0
    lastRefetching /\ setLastRefetching <- createSignal false
    lastRefetchInfo /\ setLastRefetchInfo <- createSignal ""

    resource /\ actions <- Resource.createResourceFrom source \key info -> do
      _ <- modify setFetchRuns (_ + 1)
      _ <- set setLastRefetching info.isRefetching

      case info.refetching of
        Just refetchInfo -> do
          _ <- set setLastRefetchInfo refetchInfo
          pure unit
        Nothing ->
          pure unit

      pure (Right (key * 10) :: Either String Int)

    pure
      { setSource
      , fetchRuns
      , lastRefetching
      , lastRefetchInfo
      , resource
      , actions
      , dispose
      }

  sourcedInitialStateResult <- Resource.state sourcedResourceFixture.resource
  sourcedInitialState <- expectRight "sourced state decode" sourcedInitialStateResult
  assertEqual "sourced resource starts unresolved" Resource.Unresolved sourcedInitialState

  sourcedInitialValueResult <- Resource.value sourcedResourceFixture.resource
  sourcedInitialValue <- expectRight "sourced initial value read" sourcedInitialValueResult
  assertEqual "sourced resource has no initial value" Nothing sourcedInitialValue

  sourcedInitialLoading <- Resource.loading sourcedResourceFixture.resource
  assertEqual "sourced resource starts not loading" false sourcedInitialLoading

  sourcedInitialError <- Resource.error sourcedResourceFixture.resource
  assertEqual "sourced resource starts without error" Nothing sourcedInitialError

  sourcedInitialFetchRuns <- get sourcedResourceFixture.fetchRuns
  assertEqual "sourced resource does not fetch without source" 0 sourcedInitialFetchRuns

  _ <- set sourcedResourceFixture.setSource (Just 2)

  sourcedReadyStateResult <- Resource.state sourcedResourceFixture.resource
  sourcedReadyState <- expectRight "sourced ready state decode" sourcedReadyStateResult
  assertEqual "sourced resource becomes ready after source appears" Resource.Ready sourcedReadyState

  sourcedReadyValueResult <- Resource.value sourcedResourceFixture.resource
  sourcedReadyValue <- expectRight "sourced ready value read" sourcedReadyValueResult
  assertEqual "sourced resource returns fetched value" (Just 20) sourcedReadyValue

  sourcedReadyLatestResult <- Resource.latest sourcedResourceFixture.resource
  sourcedReadyLatest <- expectRight "sourced latest read" sourcedReadyLatestResult
  assertEqual "sourced resource latest matches fetched value" (Just 20) sourcedReadyLatest

  sourcedFetchRunsAfterLoad <- get sourcedResourceFixture.fetchRuns
  assertEqual "sourced resource fetches when source changes" 1 sourcedFetchRunsAfterLoad

  sourcedLastRefetchingAfterLoad <- get sourcedResourceFixture.lastRefetching
  assertEqual "source-driven fetch is not marked as refetch" false sourcedLastRefetchingAfterLoad

  _ <- Resource.refetch sourcedResourceFixture.actions Nothing

  sourcedFetchRunsAfterRefetch <- get sourcedResourceFixture.fetchRuns
  assertEqual "manual refetch triggers fetcher" 2 sourcedFetchRunsAfterRefetch

  sourcedLastRefetchingAfterRefetch <- get sourcedResourceFixture.lastRefetching
  assertEqual "manual refetch marks fetch as refetching" true sourcedLastRefetchingAfterRefetch

  _ <- Resource.refetch sourcedResourceFixture.actions (Just "manual")

  sourcedFetchRunsAfterRefetchInfo <- get sourcedResourceFixture.fetchRuns
  assertEqual "refetch with info triggers fetcher" 3 sourcedFetchRunsAfterRefetchInfo

  sourcedLastRefetchInfo <- get sourcedResourceFixture.lastRefetchInfo
  assertEqual "refetch with info reaches fetcher" "manual" sourcedLastRefetchInfo

  _ <- Resource.mutate sourcedResourceFixture.actions (Just 99)

  sourcedMutatedValueResult <- Resource.value sourcedResourceFixture.resource
  sourcedMutatedValue <- expectRight "sourced mutated value read" sourcedMutatedValueResult
  assertEqual "mutate updates resource value" (Just 99) sourcedMutatedValue

  _ <- Resource.mutate sourcedResourceFixture.actions Nothing

  sourcedClearedValueResult <- Resource.value sourcedResourceFixture.resource
  sourcedClearedValue <- expectRight "sourced cleared value read" sourcedClearedValueResult
  assertEqual "mutate can clear resource value" Nothing sourcedClearedValue

  sourcedStateAfterMutateResult <- Resource.state sourcedResourceFixture.resource
  sourcedStateAfterMutate <- expectRight "sourced state after mutate decode" sourcedStateAfterMutateResult
  assertEqual "mutate keeps resource state ready" Resource.Ready sourcedStateAfterMutate

  sourcedResourceFixture.dispose

  errorResourceFixture <- createRoot \dispose -> do
    mode /\ setMode <- createSignal "ok"
    fetchRuns /\ setFetchRuns <- createSignal 0

    resource /\ actions <- Resource.createResource \_ -> do
      _ <- modify setFetchRuns (_ + 1)
      currentMode <- get mode

      if currentMode == "error" then
        pure (Left "resource fetch failed")
      else
        pure (Right (currentMode <> "-value"))

    pure
      { setMode
      , fetchRuns
      , resource
      , actions
      , dispose
      }

  errorFlowInitialStateResult <- Resource.state errorResourceFixture.resource
  errorFlowInitialState <- expectRight "resource initial state decode" errorFlowInitialStateResult
  assertEqual "resource without source fetches immediately" Resource.Ready errorFlowInitialState

  errorFlowInitialValueResult <- Resource.value errorResourceFixture.resource
  errorFlowInitialValue <- expectRight "resource initial value read" errorFlowInitialValueResult
  assertEqual "resource without source yields initial value" (Just "ok-value") errorFlowInitialValue

  _ <- set errorResourceFixture.setMode "error"
  _ <- Resource.refetch errorResourceFixture.actions Nothing

  errorFlowStateAfterFailureResult <- Resource.state errorResourceFixture.resource
  errorFlowStateAfterFailure <- expectRight "resource errored state decode" errorFlowStateAfterFailureResult
  assertEqual "resource enters errored state after failing fetch" Resource.Errored errorFlowStateAfterFailure

  errorFlowMessage <- Resource.error errorResourceFixture.resource
  assertEqual "resource exposes fetch error message" (Just "resource fetch failed") errorFlowMessage

  errorFlowValueAfterFailureResult <- Resource.value errorResourceFixture.resource
  case errorFlowValueAfterFailureResult of
    Left (Resource.ResourceReadError message) ->
      assertEqual "resource value read reports explicit read error" "resource fetch failed" message
    Right _ ->
      throw "resource value read should fail in errored state"

  _ <- set errorResourceFixture.setMode "recover"
  _ <- Resource.refetch errorResourceFixture.actions Nothing

  errorFlowStateAfterRecoveryResult <- Resource.state errorResourceFixture.resource
  errorFlowStateAfterRecovery <- expectRight "resource recovered state decode" errorFlowStateAfterRecoveryResult
  assertEqual "resource returns to ready state after recovery" Resource.Ready errorFlowStateAfterRecovery

  errorFlowMessageAfterRecovery <- Resource.error errorResourceFixture.resource
  assertEqual "resource clears error after successful refetch" Nothing errorFlowMessageAfterRecovery

  errorFlowValueAfterRecoveryResult <- Resource.value errorResourceFixture.resource
  errorFlowValueAfterRecovery <- expectRight "resource recovered value read" errorFlowValueAfterRecoveryResult
  assertEqual "resource exposes recovered value" (Just "recover-value") errorFlowValueAfterRecovery

  errorFlowFetchRuns <- get errorResourceFixture.fetchRuns
  assertEqual "resource fetcher runs for initial, error, and recovery flows" 3 errorFlowFetchRuns

  errorResourceFixture.dispose

  log "Context tests starting"

  createRoot \dispose -> do
    plainContext <- Context.createContext
    defaultContext <- Context.createContextWithDefault 7

    plainWithoutProvider <- Context.useContext plainContext
    assertEqual "context without provider returns Nothing" (Nothing :: Maybe Int) plainWithoutProvider

    defaultWithoutProvider <- Context.useContext defaultContext
    assertEqual "context default value is returned without provider" (Just 7) defaultWithoutProvider

    providedPlain <- Context.withContext plainContext 11 (Context.useContext plainContext)
    assertEqual "withContext provides value within current scope" (Just 11) providedPlain

    plainAfterProvide <- Context.useContext plainContext
    assertEqual "withContext restores previous scope after action" (Nothing :: Maybe Int) plainAfterProvide

    nestedValues <- Context.withContext plainContext 20 do
      outer <- Context.useContext plainContext
      inner <- Context.withContext plainContext 30 (Context.useContext plainContext)
      outerAfterInner <- Context.useContext plainContext
      pure
        { outer
        , inner
        , outerAfterInner
        }

    assertEqual "outer scope context value is visible" (Just 20) nestedValues.outer
    assertEqual "inner scope context overrides outer scope value" (Just 30) nestedValues.inner
    assertEqual "outer scope value is restored after inner override" (Just 20) nestedValues.outerAfterInner

    childScope <- Context.withContext plainContext 40 do
      createRoot \disposeChild -> do
        inherited <- Context.useContext plainContext
        pure
          { inherited
          , disposeChild
          }

    assertEqual "context value is inherited by nested ownership scope" (Just 40) childScope.inherited
    childScope.disposeChild

    nestedOwnership <- Context.withContext plainContext 50 do
      createRoot \disposeChild -> do
        childValue <- Context.useContext plainContext

        grandchildScope <- Context.withContext plainContext 60 do
          createRoot \disposeGrandchild -> do
            grandchildValue <- Context.useContext plainContext
            pure
              { grandchildValue
              , disposeGrandchild
              }

        pure
          { childValue
          , grandchildScope
          , disposeChild
          }

    assertEqual "nested ownership sees parent-provided value" (Just 50) nestedOwnership.childValue
    assertEqual "inner context override applies in deeper ownership scope" (Just 60) nestedOwnership.grandchildScope.grandchildValue

    nestedOwnership.grandchildScope.disposeGrandchild
    nestedOwnership.disposeChild

    overriddenDefault <- Context.withContext defaultContext 9 (Context.useContext defaultContext)
    assertEqual "withContext overrides default value in scope" (Just 9) overriddenDefault

    defaultAfterOverride <- Context.useContext defaultContext
    assertEqual "default value restored after scoped override" (Just 7) defaultAfterOverride

    dispose

  log "Store tests starting"

  storeFixture <- createRoot \dispose -> do
    store /\ setStore <- Store.createStore
      { count: 0
      , user:
          { age: 20
          , name: "Ada"
          }
      , settings:
          { theme: "light"
          }
      }

    pure
      { store
      , setStore
      , dispose
      }

  storeInitialCount <- Store.getField (Proxy :: Proxy "count") storeFixture.store
  assertEqual "store initial top-level field" 0 storeInitialCount

  _ <- Store.setField (Proxy :: Proxy "count") storeFixture.setStore 1
  storeCountAfterSet <- Store.getField (Proxy :: Proxy "count") storeFixture.store
  assertEqual "store setField updates top-level field" 1 storeCountAfterSet

  _ <- Store.modifyField (Proxy :: Proxy "count") storeFixture.setStore (_ + 2)
  storeCountAfterModify <- Store.getField (Proxy :: Proxy "count") storeFixture.store
  assertEqual "store modifyField updates top-level field" 3 storeCountAfterModify

  _ <- Store.modifyField (Proxy :: Proxy "user") storeFixture.setStore \user ->
    user { age = user.age + 1 }

  storeUserAfterModify <- Store.getField (Proxy :: Proxy "user") storeFixture.store
  assertEqual "store nested update via modifyField" 21 storeUserAfterModify.age

  _ <- Store.setPath storeFixture.setStore [ "user", "name" ] "Grace"

  storeUserAfterPathSet <- Store.getField (Proxy :: Proxy "user") storeFixture.store
  assertEqual "store setPath updates nested key" "Grace" storeUserAfterPathSet.name

  settingsBefore <- Store.getField (Proxy :: Proxy "settings") storeFixture.store
  userBefore <- Store.getField (Proxy :: Proxy "user") storeFixture.store

  _ <- Store.modifyPath storeFixture.setStore [ "user", "age" ] (_ + 9)

  settingsAfter <- Store.getField (Proxy :: Proxy "settings") storeFixture.store
  userAfter <- Store.getField (Proxy :: Proxy "user") storeFixture.store

  assertEqual "store modifyPath updates nested value" 30 userAfter.age
  assertEqual "store preserves untouched branch reference" true (sameRef settingsBefore settingsAfter)
  assertEqual "store preserves parent branch reference for leaf path updates" true (sameRef userBefore userAfter)

  _ <- Store.setField (Proxy :: Proxy "user") storeFixture.setStore
    { age: 31
    , name: "Grace"
    }

  userAfterSetFieldObject <- Store.getField (Proxy :: Proxy "user") storeFixture.store
  assertEqual "store setField with object keeps branch reference and merges fields" true (sameRef userAfter userAfterSetFieldObject)
  assertEqual "store setField with object updates merged age" 31 userAfterSetFieldObject.age

  unwrappedStore <- Store.unwrapStore storeFixture.store
  assertEqual "unwrapStore exposes latest nested state" 31 unwrappedStore.user.age

  storeFixture.dispose

  mutableFixture <- createRoot \dispose -> do
    mutable <- Store.createMutable
      { count: 1
      , nested:
          { value: 2
          }
      }

    pure
      { mutable
      , dispose
      }

  mutableInitialCount <- Store.getMutableField (Proxy :: Proxy "count") mutableFixture.mutable
  assertEqual "mutable initial top-level field" 1 mutableInitialCount

  _ <- Store.setMutableField (Proxy :: Proxy "count") mutableFixture.mutable 5
  mutableCountAfterSet <- Store.getMutableField (Proxy :: Proxy "count") mutableFixture.mutable
  assertEqual "mutable setMutableField updates top-level field" 5 mutableCountAfterSet

  _ <- Store.modifyMutableField (Proxy :: Proxy "count") mutableFixture.mutable (_ + 3)
  mutableCountAfterModify <- Store.getMutableField (Proxy :: Proxy "count") mutableFixture.mutable
  assertEqual "mutable modifyMutableField updates top-level field" 8 mutableCountAfterModify

  nestedBefore <- Store.getMutableField (Proxy :: Proxy "nested") mutableFixture.mutable

  _ <- Store.setMutablePath mutableFixture.mutable [ "nested", "value" ] 42
  _ <- Store.modifyMutablePath mutableFixture.mutable [ "nested", "value" ] (_ + 1)

  nestedAfter <- Store.getMutableField (Proxy :: Proxy "nested") mutableFixture.mutable
  assertEqual "mutable nested path updates value" 43 nestedAfter.value
  assertEqual "mutable nested updates keep branch reference" true (sameRef nestedBefore nestedAfter)

  unwrappedMutable <- Store.unwrapMutable mutableFixture.mutable
  assertEqual "unwrapMutable exposes latest nested state" 43 unwrappedMutable.nested.value

  mutableFixture.dispose

  log "Web tests starting"

  assertEqual "Solid.Web reports server runtime in node tests" true Web.isServer

  webBody <- Web.documentBody
  assertEqual "documentBody is unavailable without browser DOM" true (isNothing webBody)

  webMissingMount <- Web.mountById "app"
  assertEqual "mountById returns Nothing without browser DOM" true (isNothing webMissingMount)

  requiredBody <- Web.requireBody
  case requiredBody of
    Left (Web.MissingMount message) ->
      assertEqual
        "requireBody returns functional MissingMount error"
        "document.body is unavailable in current runtime"
        message
    _ ->
      throw "requireBody should return MissingMount without browser DOM"

  requiredAppMount <- Web.requireMountById "app"
  case requiredAppMount of
    Left (Web.MissingMount message) ->
      assertEqual
        "requireMountById returns functional MissingMount error"
        "No mount element found for id: app"
        message
    _ ->
      throw "requireMountById should return MissingMount when element is absent"

  renderAttempt <- Web.render (pure unit) serverMountStub
  case renderAttempt of
    Left (Web.ClientOnlyApi message) ->
      assertEqual
        "render returns client-only error value on server runtime"
        "Client-only API called on the server side. Run client-only code in onMount, or conditionally run client-only component with <Show>."
        message
    Left other ->
      throw ("render should classify as ClientOnlyApi, got " <> show other)
    Right _ ->
      throw "render should return Left on server runtime"

  hydrateAttempt <- Web.hydrate (pure unit) serverMountStub
  case hydrateAttempt of
    Left (Web.ClientOnlyApi message) ->
      assertEqual
        "hydrate returns client-only error value on server runtime"
        "Client-only API called on the server side. Run client-only code in onMount, or conditionally run client-only component with <Show>."
        message
    Left other ->
      throw ("hydrate should classify as ClientOnlyApi, got " <> show other)
    Right _ ->
      throw "hydrate should return Left on server runtime"

  log "All tests passed"
