-- | Internal: not part of the public API.
module Solid.Internal.Setup
  ( Setup(..)
  , runSetup
  , class MonadReactive
  , liftReactive
  ) where

import Prelude

import Control.Monad.Rec.Class (class MonadRec)
import Effect (Effect)

-- | Code that runs inside a reactive owner: a component body, a `createRoot`
-- | body, a list-item mapper.
newtype Setup a = Setup (Effect a)

derive newtype instance Functor Setup
derive newtype instance Apply Setup
derive newtype instance Applicative Setup
derive newtype instance Bind Setup
derive newtype instance Monad Setup
derive newtype instance MonadRec Setup
derive newtype instance Semigroup a => Semigroup (Setup a)
derive newtype instance Monoid a => Monoid (Setup a)

runSetup :: forall a. Setup a -> Effect a
runSetup (Setup effect) = effect

-- | Monads that may create signals and roots: `Effect` (unowned) and `Setup` (owned).
class Monad m <= MonadReactive m where
  liftReactive :: forall a. Effect a -> m a

instance MonadReactive Effect where
  liftReactive = identity

instance MonadReactive Setup where
  liftReactive = Setup
