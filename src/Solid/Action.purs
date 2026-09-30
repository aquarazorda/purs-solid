-- | Actions: async mutations as one transaction. Every `liftAff` is a
-- | suspension point that re-enters the transaction; nothing is committed until
-- | the action finishes. Optimistic values revert when it settles.
module Solid.Action
  ( action
  , Optimistic
  , createOptimistic
  , createOptimisticWith
  , createOptimisticFrom
  , createOptimisticFromWith
  , setOptimistic
  , modifyOptimistic
  , affects
  , module Exports
  ) where

import Prelude

import Control.Promise (Promise, fromAff, toAffE)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (liftAff) as Exports
import Effect.Class (liftEffect) as Exports
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Prim.Row as Row
import Solid.Reactivity (MemoOptions)
import Solid.Internal.Action (Action(..), liftActionEffect)
import Solid.Internal.Action (Action) as Exports
import Solid.Internal.Optimistic (class MonadOptimistic, liftOptimistic)
import Solid.Internal.Setup (class MonadReactive, Setup(..), liftReactive)
import Solid.Async (Refresh)
import Solid.Internal.Tracked (class Tracked, Accessor, fromAccessor, toAccessor)
import Solid.Signal (SignalOptions)

-- | Runs each call as one transaction. Call it from event handlers or other
-- | `Aff` code; Solid rejects actions started in owned scopes.
action :: forall a r. (a -> Action r) -> a -> Aff r
action steps = \input -> toAffE (runEffectFn1 run input)
  where
  run = actionImpl eliminate fromAff steps

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

foreign import data Optimistic :: Type -> Type

-- | A value that can be overridden tentatively during an action and reverts
-- | to `initial` when the action settles.
createOptimistic :: forall m a. MonadReactive m => a -> m (Accessor a /\ Optimistic a)
createOptimistic = createOptimisticWith {}

-- | Takes any subset of `SignalOptions`.
createOptimisticWith
  :: forall m a given missing
   . MonadReactive m
  => Row.Union given missing (SignalOptions a)
  => { | given }
  -> a
  -> m (Accessor a /\ Optimistic a)
createOptimisticWith options initial = liftReactive do
  parts <- runEffectFn2 createOptimisticImpl options initial
  pure (parts.get /\ parts.set)

foreign import createOptimisticImpl :: forall options a. EffectFn2 { | options } a { get :: Accessor a, set :: Optimistic a }

-- | An optimistic view of `source`: tentative writes during an action, then
-- | back to following `source`.
createOptimisticFrom :: forall f a. Tracked f => f a -> Setup (f a /\ Optimistic a)
createOptimisticFrom = createOptimisticFromWith {}

-- | Takes any subset of `MemoOptions`.
createOptimisticFromWith
  :: forall f a given missing
   . Tracked f
  => Row.Union given missing (MemoOptions a)
  => { | given }
  -> f a
  -> Setup (f a /\ Optimistic a)
createOptimisticFromWith options source = Setup do
  parts <- runEffectFn2 createOptimisticFromImpl options (toAccessor source)
  pure (fromAccessor parts.get /\ parts.set)

foreign import createOptimisticFromImpl :: forall options a. EffectFn2 { | options } (Accessor a) { get :: Accessor a, set :: Optimistic a }

-- | A tentative write: in an `Action`, or in a router action's `onSubmit`.
setOptimistic :: forall m a. MonadOptimistic m => Optimistic a -> a -> m Unit
setOptimistic setter value = liftOptimistic (setOptimisticImpl setter value)

modifyOptimistic :: forall m a. MonadOptimistic m => Optimistic a -> (a -> a) -> m Unit
modifyOptimistic setter f = liftOptimistic (modifyOptimisticImpl setter f)

foreign import setOptimisticImpl :: forall a. Optimistic a -> a -> Effect Unit
foreign import modifyOptimisticImpl :: forall a. Optimistic a -> (a -> a) -> Effect Unit

-- | Marks an async value as pending until the action settles, e.g. before a
-- | `refresh` (which alone doesn't set `isPending`).
affects :: forall a. Refresh a -> Action Unit
affects target = liftActionEffect (runEffectFn1 affectsImpl target)

foreign import affectsImpl :: forall a. EffectFn1 (Refresh a) Unit
