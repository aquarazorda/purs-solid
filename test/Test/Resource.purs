module Test.Resource
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Exception (throw)
import Solid.Resource as Resource
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, modify, set)
import Test.Assert (assertEqual, expectRight)

run :: Effect Unit
run = do
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
