-- | Owners: the scopes that dispose reactive computations.
module Solid.Owner
  ( Owner
  , getOwner
  , runWithOwner
  ) where

import Effect (Effect)
import Effect.Uncurried (EffectFn2, runEffectFn2)
import Solid.Internal.Setup (Setup(..), runSetup)

foreign import data Owner :: Type

-- | The current owner. Total: `Setup` code always runs under one.
getOwner :: Setup Owner
getOwner = Setup getOwnerImpl

foreign import getOwnerImpl :: Effect Owner

-- | Runs `Setup` code under a captured owner, from `Effect` code such as an
-- | event handler or an async callback. Anything it creates is disposed with
-- | that owner.
runWithOwner :: forall a. Owner -> Setup a -> Effect a
runWithOwner owner setup = runEffectFn2 runWithOwnerImpl owner (runSetup setup)

foreign import runWithOwnerImpl :: forall a. EffectFn2 Owner (Effect a) a
