-- | `Setup` is the monad for code that runs inside a reactive owner. It has no
-- | `MonadEffect`, so writing signals or reading untracked during setup doesn't
-- | compile. `Effect` code enters it through `createRoot` or `runWithOwner`.
module Solid.Setup
  ( module Exports
  , liftSetup
  ) where

import Effect (Effect)
import Solid.Internal.Setup (Setup(..))
import Solid.Internal.Setup (Setup, class MonadReactive) as Exports

-- | Runs an arbitrary effect during setup, e.g. `Ref.new`. The effect must not
-- | write signals or stores; the types can't tell, but Solid's dev build
-- | reports such a write (`REACTIVE_WRITE_IN_OWNED_SCOPE`).
liftSetup :: forall a. Effect a -> Setup a
liftSetup = Setup
