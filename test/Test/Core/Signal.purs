module Test.Core.Signal
  ( spec
  ) where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Solid.Reactivity (createEffect_, createMemo, flush)
import Solid.Root (createRoot)
import Solid.Signal (Accessor, alwaysNotify, createSignal, createSignalWith, eqEquality, get, modify, set, untrack)
import Test.Solid (settle, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "Solid.Signal" do
  solidIt "writes become visible after the flush" do
    result <- liftEffect do
      count /\ setCount <- createSignal 0
      set setCount 1
      before <- get count
      flush
      after <- get count
      pure { before, after }
    result `shouldEqual` { before: 0, after: 1 }

  solidIt "modify returns the value it wrote, chaining through pending writes" do
    result <- liftEffect do
      count /\ setCount <- createSignal 1
      first <- modify setCount (_ + 1)
      second <- modify setCount (_ * 10)
      flush
      final <- get count
      pure { first, second, final }
    result `shouldEqual` { first: 2, second: 20, final: 20 }

  solidIt "stores function values instead of calling them" do
    result <- liftEffect do
      fn /\ setFn <- createSignal (\n -> n + 1)
      initial <- (_ $ 1) <$> get fn
      set setFn (\n -> n * 10)
      flush
      updated <- (_ $ 3) <$> get fn
      pure { initial, updated }
    result `shouldEqual` { initial: 2, updated: 30 }

  solidIt "stores Effect values without running them" do
    runs <- liftEffect (Ref.new 0)
    liftEffect do
      action /\ setAction <- createSignal (Ref.modify_ (_ + 1) runs)
      set setAction (Ref.modify_ (_ + 100) runs)
      flush
      join (get action)
    liftEffect (Ref.read runs) >>= shouldEqual 100

  describe "Accessor instances" do
    solidIt "Functor / Apply derive values that follow their sources" do
      result <- liftEffect do
        a /\ setA <- createSignal 2
        b /\ _ <- createSignal 3
        let sum = (+) <$> a <*> b
        before <- get sum
        set setA 10
        flush
        after <- get sum
        pure { before, after }
      result `shouldEqual` { before: 5, after: 13 }

    solidIt "Monad laws hold" do
      result <- liftEffect do
        a /\ _ <- createSignal 4
        let f n = pure (n * 2) :: Accessor Int
        leftIdentity <- (==) <$> get (pure 4 >>= f) <*> get (f 4)
        rightIdentity <- (==) <$> get (a >>= pure) <*> get a
        functorIdentity <- (==) <$> get (identity <$> a) <*> get a
        pure [ leftIdentity, rightIdentity, functorIdentity ]
      result `shouldEqual` [ true, true, true ]

    solidIt "HeytingAlgebra combines boolean accessors" do
      result <- liftEffect do
        a /\ setA <- createSignal true
        b /\ _ <- createSignal true
        let both = a && b
        before <- get both
        set setA false
        flush
        after <- get both
        pure { before, after }
      result `shouldEqual` { before: true, after: false }

  describe "equality" do
    solidIt "reference equality notifies for an equal but new record" do
      runs <- countEffectRuns (createSignalWith {})
      runs `shouldEqual` 2

    solidIt "eqEquality skips an equal record" do
      runs <- countEffectRuns (createSignalWith { equals: eqEquality })
      runs `shouldEqual` 1

    solidIt "alwaysNotify notifies even for the same value" do
      runs <- liftEffect (Ref.new 0)
      setValue <- liftEffect $ createRoot \_ -> do
        value /\ setValue <- createSignalWith { equals: alwaysNotify } 1
        createEffect_ value \_ -> Ref.modify_ (_ + 1) runs
        pure setValue
      settle
      liftEffect (set setValue 1)
      settle
      liftEffect (Ref.read runs) >>= shouldEqual 2

  solidIt "untrack reads without subscribing" do
    runs <- liftEffect (Ref.new 0)
    setters <- liftEffect $ createRoot \_ -> do
      tracked /\ setTracked <- createSignal 1
      ignored /\ setIgnored <- createSignal 10
      total <- createMemo ((+) <$> tracked <*> untrack ignored)
      createEffect_ total \_ -> Ref.modify_ (_ + 1) runs
      pure { setTracked, setIgnored }
    settle
    liftEffect (set setters.setIgnored 20)
    settle
    liftEffect (Ref.read runs) >>= shouldEqual 1
    liftEffect (set setters.setTracked 2)
    settle
    liftEffect (Ref.read runs) >>= shouldEqual 2
  where
  countEffectRuns create = do
    runs <- liftEffect (Ref.new 0)
    setValue <- liftEffect $ createRoot \_ -> do
      value /\ setValue <- create { n: 1 }
      createEffect_ value \_ -> Ref.modify_ (_ + 1) runs
      pure setValue
    settle
    liftEffect (set setValue { n: 1 })
    settle
    liftEffect (Ref.read runs)
