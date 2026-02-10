module Test.Signal
  ( run
  ) where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Reactivity (createEffect, createMemo, createMemoWith, defaultMemoOptions)
import Solid.Root (createRoot)
import Solid.Signal (Equality(..), createSignal, createSignalWith, defaultSignalOptions, get, modify, set)
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
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

  memoEqualityFixture <- createRoot \dispose -> do
    source /\ setSource <- createSignal 0
    alwaysEqRuns /\ setAlwaysEqRuns <- createSignal 0
    neverEqRuns /\ setNeverEqRuns <- createSignal 0

    alwaysEqMemo <- createMemoWith
      (defaultMemoOptions { equality = CustomEquals (\_ _ -> true) })
      (get source)

    neverEqMemo <- createMemoWith
      (defaultMemoOptions { equality = CustomEquals (\_ _ -> false) })
      do
        _ <- get source
        pure 0

    _ <- createEffect do
      _ <- get alwaysEqMemo
      _ <- modify setAlwaysEqRuns (_ + 1)
      pure unit

    _ <- createEffect do
      _ <- get neverEqMemo
      _ <- modify setNeverEqRuns (_ + 1)
      pure unit

    pure
      { setSource
      , alwaysEqMemo
      , alwaysEqRuns
      , neverEqRuns
      , dispose
      }

  _ <- set memoEqualityFixture.setSource 1
  _ <- set memoEqualityFixture.setSource 2

  alwaysEqRuns <- get memoEqualityFixture.alwaysEqRuns
  assertEqual "createMemoWith custom equals true suppresses downstream reruns" 1 alwaysEqRuns

  alwaysEqValue <- get memoEqualityFixture.alwaysEqMemo
  assertEqual "createMemoWith custom equals true preserves previous memo value" 0 alwaysEqValue

  neverEqRuns <- get memoEqualityFixture.neverEqRuns
  assertEqual "createMemoWith custom equals false always notifies dependents" 3 neverEqRuns

  memoEqualityFixture.dispose
