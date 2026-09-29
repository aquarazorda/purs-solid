module Solid.Lifecycle
  ( onCleanup
  , onSettled
  , onSettled_
  ) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, runEffectFn1)
import Solid.Internal.Setup (Setup(..))

-- | Runs when the current owner is disposed or re-runs. Cleanups run in reverse
-- | registration order.
onCleanup :: Effect Unit -> Setup Unit
onCleanup cleanup = Setup (runEffectFn1 onCleanupImpl cleanup)

foreign import onCleanupImpl :: EffectFn1 (Effect Unit) Unit

-- | Runs once the current owner's subtree has settled: rendered and with no
-- | async work pending (Solid 1's `onMount`). The returned `Effect Unit` runs
-- | on disposal. Don't create reactive primitives inside the callback.
onSettled :: Effect (Effect Unit) -> Setup Unit
onSettled callback = Setup (runEffectFn1 onSettledImpl callback)

-- | `onSettled` without a cleanup.
onSettled_ :: Effect Unit -> Setup Unit
onSettled_ callback = onSettled (callback $> pure unit)

foreign import onSettledImpl :: EffectFn1 (Effect (Effect Unit)) Unit
