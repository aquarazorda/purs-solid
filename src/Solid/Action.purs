-- | Actions: async mutations as one transaction.
-- |
-- | An `Action` interleaves effects (writes) with async work. Every `liftAff`
-- | is a transaction-safe suspension point: the runtime waits for it and
-- | re-enters the transaction before the next step. (Solid's JS API only does
-- | that after a `yield`, not after a plain `await`; here there is no other
-- | way to wait, so the mistake can't be written.) The UI sees one atomic
-- | update per step, and nothing is committed until the action finishes.
-- |
-- | Optimistic values show a tentative value while an action runs and revert
-- | when it settles, whether it succeeds or fails. Their writes exist only as
-- | `Action` steps, so they can't be made outside an action, where they'd have
-- | nothing to revert with. Write the real result to ordinary signals or
-- | stores within the same action.
-- |
-- | ```purescript
-- | saving /\ setSaving <- createOptimistic false
-- |
-- | save = action \draft -> do
-- |   setOptimistic setSaving true
-- |   saved <- liftAff (Api.save draft)
-- |   liftEffect (Signal.set setTodos saved)
-- | ```
module Solid.Action
  ( action
  , Optimistic
  , createOptimistic
  , createOptimisticFrom
  , setOptimistic
  , modifyOptimistic
  , module Exports
  ) where

import Prelude

import Control.Promise (Promise, fromAff, toAffE)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (liftAff) as Exports
import Effect.Class (liftEffect) as Exports
import Effect.Uncurried (EffectFn1, runEffectFn1)
import Solid.Internal.Action (Action(..), liftActionEffect)
import Solid.Internal.Action (Action) as Exports
import Solid.Internal.Setup (class MonadReactive, Setup(..), liftReactive)
import Solid.Signal (Accessor)

-- | Turns a step sequence into a function that runs each call as one
-- | transaction and completes with its result (or fails with its error).
-- | Call it from `Effect` / `Aff` code such as event handlers; Solid rejects
-- | actions started in owned scopes, and `Setup` can't run an `Aff`.
action :: forall a r. (a -> Action r) -> a -> Aff r
action steps = \input -> toAffE (runEffectFn1 run input)
  where
  run = actionImpl eliminate fromAff steps

-- | Lets the FFI walk an `Action` without depending on its representation.
eliminate
  :: forall a r
   . (a -> r)
  -> (Effect (Action a) -> r)
  -> (Aff (Action a) -> r)
  -> Action a
  -> r
eliminate done write await = case _ of
  Done value -> done value
  Write effect -> write effect
  Await aff -> await aff

foreign import actionImpl
  :: forall a r
   . (forall x y. (x -> y) -> (Effect (Action x) -> y) -> (Aff (Action x) -> y) -> Action x -> y)
  -> (forall x. Aff x -> Effect (Promise x))
  -> (a -> Action r)
  -> EffectFn1 a (Promise r)

-- | The capability to write an optimistic value (only from an `Action`).
foreign import data Optimistic :: Type -> Type

-- | A value that can be overridden tentatively during an action and reverts
-- | to `initial` when the action settles (e.g. a "saving" flag).
createOptimistic :: forall m a. MonadReactive m => a -> m (Accessor a /\ Optimistic a)
createOptimistic initial = liftReactive do
  parts <- runEffectFn1 createOptimisticImpl initial
  pure (parts.get /\ parts.set)

foreign import createOptimisticImpl :: forall a. EffectFn1 a { get :: Accessor a, set :: Optimistic a }

-- | An optimistic view of `source`: tentative writes during an action, then
-- | back to following `source` (which the action has usually just updated).
createOptimisticFrom :: forall a. Accessor a -> Setup (Accessor a /\ Optimistic a)
createOptimisticFrom source = Setup do
  parts <- runEffectFn1 createOptimisticFromImpl source
  pure (parts.get /\ parts.set)

foreign import createOptimisticFromImpl :: forall a. EffectFn1 (Accessor a) { get :: Accessor a, set :: Optimistic a }

setOptimistic :: forall a. Optimistic a -> a -> Action Unit
setOptimistic setter value = liftActionEffect (setOptimisticImpl setter value)

modifyOptimistic :: forall a. Optimistic a -> (a -> a) -> Action Unit
modifyOptimistic setter f = liftActionEffect (modifyOptimisticImpl setter f)

foreign import setOptimisticImpl :: forall a. Optimistic a -> a -> Effect Unit
foreign import modifyOptimisticImpl :: forall a. Optimistic a -> (a -> a) -> Effect Unit
