module Test.Core.Action
  ( spec
  ) where

import Prelude

import Data.Either (isLeft)
import Data.Tuple.Nested ((/\))
import Effect.Aff (Milliseconds(..), delay, forkAff, joinFiber, throwError, try)
import Effect.Class (liftEffect)
import Effect.Exception (error)
import Solid.Action (action, createOptimistic, createOptimisticFrom, liftAff, setOptimistic)
import Solid.Action as Action
import Solid.Reactivity (createEffect_, flush)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get)
import Solid.Signal as Signal
import Solid.Store (createOptimisticStore, createStore, focus, key, value)
import Solid.Store as Store
import Test.Solid (solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "Solid.Action" do
  solidIt "runs its steps and completes with the result" do
    total /\ setTotal <- liftEffect (createSignal 0)
    let
      addLater = action \n -> do
        x <- liftAff (delay (Milliseconds 5.0) $> n)
        Action.liftEffect (Signal.set setTotal x)
        pure (x * 2)
    result <- addLater 21
    liftEffect flush
    committed <- liftEffect (get total)
    { result, committed } `shouldEqual` { result: 42, committed: 21 }

  solidIt "optimistic values show during the action; real writes commit at the end" do
    parts <- liftEffect $ createRoot \_ -> do
      saved /\ setSaved <- createSignal "old"
      saving /\ setSaving <- createOptimistic false
      -- Observe both, as a rendered view would.
      createEffect_ (Tuple' <$> saved <*> saving) \_ -> pure unit
      pure { saved, setSaved, saving, setSaving }
    let
      save = action \next -> do
        setOptimistic parts.setSaving true
        -- A real write before the async step: held by the transaction until
        -- the action completes, while the optimistic value shows at once.
        Action.liftEffect (Signal.set parts.setSaved next)
        liftAff (delay (Milliseconds 20.0))
    running <- forkAff (save "new")
    delay (Milliseconds 5.0)
    liftEffect flush
    during <- liftEffect ({ saving: _, saved: _ } <$> get parts.saving <*> get parts.saved)
    joinFiber running
    liftEffect flush
    after <- liftEffect ({ saving: _, saved: _ } <$> get parts.saving <*> get parts.saved)
    during `shouldEqual` { saving: true, saved: "old" }
    after `shouldEqual` { saving: false, saved: "new" }

  solidIt "a failing action rejects and its optimistic writes revert" do
    parts <- liftEffect $ createRoot \_ -> do
      saving /\ setSaving <- createOptimistic false
      createEffect_ saving \_ -> pure unit
      pure { saving, setSaving }
    let
      save = action \_ -> do
        setOptimistic parts.setSaving true
        liftAff (delay (Milliseconds 5.0))
        liftAff (throwError (error "offline")) :: _ Unit
    result <- try (save unit)
    liftEffect flush
    after <- liftEffect (get parts.saving)
    { failed: isLeft result, after } `shouldEqual` { failed: true, after: false }

  solidIt "createOptimisticFrom follows its source once the action settles" do
    parts <- liftEffect $ createRoot \_ -> do
      count /\ setCount <- createSignal 1
      shown /\ setShown <- createOptimisticFrom count
      createEffect_ shown \_ -> pure unit
      pure { shown, setCount, setShown }
    let
      increment = action \_ -> do
        setOptimistic parts.setShown 2
        liftAff (delay (Milliseconds 10.0))
        Action.liftEffect (Signal.set parts.setCount 2)
    running <- forkAff (increment unit)
    delay (Milliseconds 3.0)
    liftEffect flush
    during <- liftEffect (get parts.shown)
    joinFiber running
    liftEffect flush
    after <- liftEffect (get parts.shown)
    { during, after } `shouldEqual` { during: 2, after: 2 }

  solidIt "optimistic store updates show during the action only" do
    parts <- liftEffect $ createRoot \_ -> do
      saved /\ setSaved <- createStore { items: [ "a" ] }
      pending /\ setPending <- createOptimisticStore { items: [] :: Array String }
      createEffect_ (Tuple' <$> value saved <*> value pending) \_ -> pure unit
      pure { saved, setSaved, pending, setPending }
    let
      add = action \item -> do
        Store.updateOptimistic parts.setPending (Store.at (key @"items") (Store.push item))
        liftAff (delay (Milliseconds 10.0))
        Action.liftEffect (Store.update parts.setSaved (Store.at (key @"items") (Store.push item)))
    running <- forkAff (add "b")
    delay (Milliseconds 3.0)
    liftEffect flush
    during <- liftEffect (get (value (focus (key @"items") parts.pending)))
    joinFiber running
    liftEffect flush
    afterPending <- liftEffect (get (value (focus (key @"items") parts.pending)))
    afterSaved <- liftEffect (get (value (focus (key @"items") parts.saved)))
    { during, afterPending, afterSaved } `shouldEqual` { during: [ "b" ], afterPending: [], afterSaved: [ "a", "b" ] }

data Tuple' a b = Tuple' a b
