module Solid.Root
  ( createRoot
  ) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1, runEffectFn1)
import Solid.Internal.Setup (class MonadReactive, Setup, liftReactive, runSetup)

-- | Runs `body` in a new owner and returns its result. The `Effect Unit`
-- | passed to `body` disposes the root.
-- |
-- | From `Effect` the root is detached; from `Setup` it's owned by the current
-- | owner and disposed with it (Solid 2 semantics).
-- |
-- | The body is `Setup`, so it can't write signals: return the setters and
-- | write from `Effect` once the root is created.
createRoot :: forall m a. MonadReactive m => (Effect Unit -> Setup a) -> m a
createRoot body =
  liftReactive (runEffectFn1 createRootImpl (mkEffectFn1 (runSetup <<< body)))

foreign import createRootImpl :: forall a. EffectFn1 (EffectFn1 (Effect Unit) a) a
