-- | Internal: the monads optimistic writes may run in (only `Solid.Action.Action`),
-- | kept as a class so `Solid.Store` doesn't depend on `Aff`.
module Solid.Internal.Optimistic
  ( class MonadOptimistic
  , liftOptimistic
  ) where

import Prelude

import Effect (Effect)

class Monad m <= MonadOptimistic m where
  liftOptimistic :: forall a. Effect a -> m a
