module Test.Core.Reactivity
  ( spec
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import Effect.Ref as Ref
import Partial.Unsafe (unsafeCrashWith)
import Solid.Reactivity (createEffect, createEffectWith, createEffect_, createMemo, createReaction, createRenderEffect_, createWritableMemo, defaultEffectOptions, flush, track, withFlush)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, set)
import Test.Solid (settle, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

logTo :: Ref.Ref (Array String) -> String -> Effect Unit
logTo ref entry = Ref.modify_ (_ <> [ entry ]) ref

spec :: Spec Unit
spec = describe "Solid.Reactivity" do
  describe "createMemo" do
    solidIt "notifies only when its result changes" do
      log <- liftEffect (Ref.new [])
      setSource <- liftEffect $ createRoot \_ -> do
        source /\ setSource <- createSignal 1
        bucket <- createMemo ((_ `div` 10) <$> source)
        createEffect_ bucket \b -> logTo log (show b)
        pure setSource
      settle
      liftEffect (set setSource 5)
      settle
      liftEffect (set setSource 12)
      settle
      liftEffect (Ref.read log) >>= shouldEqual [ "0", "1" ]

    solidIt "tracks dependencies dynamically through bind" do
      log <- liftEffect (Ref.new [])
      setters <- liftEffect $ createRoot \_ -> do
        useLeft /\ setUseLeft <- createSignal true
        left /\ setLeft <- createSignal "L1"
        right /\ setRight <- createSignal "R1"
        chosen <- createMemo do
          flag <- useLeft
          if flag then left else right
        createEffect_ chosen (logTo log)
        pure { setUseLeft, setLeft, setRight }
      settle
      -- `right` isn't a dependency while `useLeft` is true.
      liftEffect (set setters.setRight "R2")
      settle
      liftEffect (set setters.setUseLeft false)
      settle
      liftEffect (set setters.setLeft "L2")
      settle
      liftEffect (Ref.read log) >>= shouldEqual [ "L1", "R2" ]

  describe "createWritableMemo" do
    solidIt "a write wins until a dependency changes" do
      result <- liftEffect do
        parts <- createRoot \_ -> do
          source /\ setSource <- createSignal 5
          derived /\ setDerived <- createWritableMemo ((_ * 10) <$> source)
          pure { derived, setSource, setDerived }
        initial <- withFlush (get parts.derived)
        withFlush (set parts.setDerived 99)
        written <- get parts.derived
        withFlush (set parts.setSource 6)
        rederived <- get parts.derived
        pure [ initial, written, rederived ]
      result `shouldEqual` [ 50, 99, 60 ]

  describe "createEffect" do
    solidIt "runs cleanups before the next apply and on dispose" do
      log <- liftEffect (Ref.new [])
      parts <- liftEffect $ createRoot \dispose -> do
        value /\ setValue <- createSignal 0
        createEffect value \v -> do
          logTo log ("apply " <> show v)
          pure (logTo log ("cleanup " <> show v))
        pure { setValue, dispose }
      settle
      liftEffect (set parts.setValue 1)
      settle
      liftEffect parts.dispose
      liftEffect (Ref.read log) >>= shouldEqual [ "apply 0", "cleanup 0", "apply 1", "cleanup 1" ]

    solidIt "defer skips the initial apply" do
      log <- liftEffect (Ref.new [])
      setValue <- liftEffect $ createRoot \_ -> do
        value /\ setValue <- createSignal 0
        createEffectWith (defaultEffectOptions { defer = true }) value \v -> do
          logTo log (show v)
          pure (pure unit)
        pure setValue
      settle
      liftEffect (set setValue 1)
      settle
      liftEffect (Ref.read log) >>= shouldEqual [ "1" ]

    solidIt "onError receives compute-phase errors" do
      log <- liftEffect (Ref.new [])
      setValue <- liftEffect $ createRoot \_ -> do
        value /\ setValue <- createSignal 0
        let checked = value <#> \v -> if v > 0 then unsafeCrashWith "boom" else v
        createEffectWith (defaultEffectOptions { onError = Just (logTo log <<< message) }) checked \v -> do
          logTo log ("apply " <> show v)
          pure (pure unit)
        pure setValue
      settle
      liftEffect (set setValue 1)
      settle
      entries <- liftEffect (Ref.read log)
      Array.take 1 entries `shouldEqual` [ "apply 0" ]
      Array.length entries `shouldEqual` 2

    solidIt "createRenderEffect applies synchronously during the flush" do
      log <- liftEffect (Ref.new [])
      setValue <- liftEffect $ createRoot \_ -> do
        value /\ setValue <- createSignal "a"
        createRenderEffect_ value (logTo log)
        pure setValue
      liftEffect do
        withFlush (set setValue "b")
      liftEffect (Ref.read log) >>= shouldEqual [ "a", "b" ]

  describe "createReaction" do
    solidIt "fires once after a tracked change" do
      fired <- liftEffect (Ref.new 0)
      parts <- liftEffect $ createRoot \_ -> do
        value /\ setValue <- createSignal 0
        reaction <- createReaction (Ref.modify_ (_ + 1) fired)
        pure { value, setValue, reaction }
      liftEffect (track parts.reaction parts.value)
      liftEffect (set parts.setValue 1)
      settle
      liftEffect (set parts.setValue 2)
      settle
      liftEffect (Ref.read fired) >>= shouldEqual 1

  solidIt "flush applies pending writes immediately" do
    result <- liftEffect do
      value /\ setValue <- createSignal "old"
      set setValue "new"
      flush
      get value
    result `shouldEqual` "new"
