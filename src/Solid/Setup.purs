-- | `Setup` is the monad for code that runs inside a reactive owner:
-- | component bodies, `createRoot` bodies and list-item mappers.
-- |
-- | Solid 2 rejects some operations in owned scopes at runtime (dev only):
-- | writing signals (`REACTIVE_WRITE_IN_OWNED_SCOPE`), calling `refresh` or
-- | actions, and reading reactive values untracked at the top of a component.
-- | `Setup` makes those mistakes compile errors instead: it has no
-- | `MonadEffect` instance, signal writes live in `Effect`, and there is no
-- | `get` in `Setup` (compose `Accessor`s, or `sample` explicitly).
-- |
-- | Owned primitives (`createMemo`, `createEffect`, `onCleanup`, ...) exist only
-- | in `Setup`, so they can't be created where nothing would dispose them.
-- | `Effect` code enters `Setup` through `createRoot` or `runWithOwner`.
module Solid.Setup
  ( module Exports
  , liftSetup
  ) where

import Effect (Effect)
import Solid.Internal.Setup (Setup(..))
import Solid.Internal.Setup (Setup, class MonadReactive) as Exports

-- | Runs an arbitrary effect during setup, e.g. `Ref.new` or logging.
-- |
-- | This is the one way around the guarantee above, so the effect must not
-- | write signals or stores. Solid's dev build still reports it if it does
-- | (`REACTIVE_WRITE_IN_OWNED_SCOPE`).
liftSetup :: forall a. Effect a -> Setup a
liftSetup = Setup
