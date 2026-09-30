module Solid.Root
  ( createRoot
  ) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1, runEffectFn1)
import Solid.Internal.Setup (class MonadReactive, Setup, liftReactive, runSetup)

-- | Runs `body` in a new owner; the `Effect Unit` passed to it disposes the root.
-- | From `Effect` the root is detached; from `Setup` it's disposed with the current owner.
-- | The body can't write signals: return the setters and write from `Effect`.
createRoot :: forall m a. MonadReactive m => (Effect Unit -> Setup a) -> m a
createRoot body =
  liftReactive (runEffectFn1 createRootImpl (mkEffectFn1 (runSetup <<< body)))

foreign import createRootImpl :: forall a. EffectFn1 (EffectFn1 (Effect Unit) a) a
