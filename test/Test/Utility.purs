module Test.Utility
  ( run
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Reactivity (createEffect)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, modify, set)
import Solid.Utility (batch, defaultOnOptions, on, onWith, untrack)
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
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
