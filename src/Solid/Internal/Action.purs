-- | Internal: not part of the public API.
module Solid.Internal.Action
  ( Action(..)
  , liftActionEffect
  ) where

import Prelude

import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (class MonadEffect)
import Solid.Internal.Optimistic (class MonadOptimistic)

-- | A sequence of steps: effects run inside the transaction, async work
-- | suspends it and re-enters it when done.
data Action a
  = Done a
  | Write (Effect (Action a))
  | Await (Aff (Action a))

instance Functor Action where
  map f = case _ of
    Done a -> Done (f a)
    Write effect -> Write (map f <$> effect)
    Await aff -> Await (map f <$> aff)

instance Apply Action where
  apply = ap

instance Applicative Action where
  pure = Done

instance Bind Action where
  bind step f = case step of
    Done a -> f a
    Write effect -> Write ((_ >>= f) <$> effect)
    Await aff -> Await ((_ >>= f) <$> aff)

instance Monad Action

instance MonadEffect Action where
  liftEffect = liftActionEffect

instance MonadAff Action where
  liftAff aff = Await (Done <$> aff)

instance MonadOptimistic Action where
  liftOptimistic = liftActionEffect

liftActionEffect :: forall a. Effect a -> Action a
liftActionEffect effect = Write (Done <$> effect)
