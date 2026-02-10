module Test.Lifecycle
  ( run
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Exception (throw)
import Solid.Lifecycle (onCleanup, onMount)
import Solid.Reactivity (createEffect)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, modify, set)
import Solid.Utility (getOwner, runWithOwner)
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
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

  cleanupRerunFixture <- createRoot \dispose -> do
    source /\ setSource <- createSignal 0
    effectRuns /\ setEffectRuns <- createSignal 0
    cleanupRuns /\ setCleanupRuns <- createSignal 0

    _ <- createEffect do
      _ <- get source
      _ <- modify setEffectRuns (_ + 1)
      _ <- onCleanup do
        _ <- modify setCleanupRuns (_ + 1)
        pure unit
      pure unit

    pure
      { setSource
      , effectRuns
      , cleanupRuns
      , dispose
      }

  initialEffectRuns <- get cleanupRerunFixture.effectRuns
  assertEqual "createEffect runs once initially for cleanup test" 1 initialEffectRuns

  initialCleanupRuns <- get cleanupRerunFixture.cleanupRuns
  assertEqual "effect cleanup has not run before dependency change" 0 initialCleanupRuns

  _ <- set cleanupRerunFixture.setSource 1

  effectRunsAfterDependencyChange <- get cleanupRerunFixture.effectRuns
  assertEqual "createEffect reruns when dependency changes" 2 effectRunsAfterDependencyChange

  cleanupRunsAfterDependencyChange <- get cleanupRerunFixture.cleanupRuns
  assertEqual "effect cleanup runs before rerun on dependency change" 1 cleanupRunsAfterDependencyChange

  cleanupRerunFixture.dispose

  cleanupRunsAfterDisposal <- get cleanupRerunFixture.cleanupRuns
  assertEqual "effect cleanup runs on disposal after dependency reruns" 2 cleanupRunsAfterDisposal
