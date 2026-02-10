module Test.Secondary
  ( run
  ) where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Reactivity (createComputed, createEffect, createReaction, createRenderEffect, createSelector)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, modify, set)
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
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
