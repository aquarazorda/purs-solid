module Solid.Root
  ( createRoot
  , RootOptions
  , createRootWith
  ) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn2)
import Prim.Row as Row
import Solid.Internal.Setup (class MonadReactive, Setup, liftReactive, runSetup)

-- | Runs `body` in a new owner; the `Effect Unit` passed to it disposes the root.
-- | From `Effect` the root is detached; from `Setup` it's disposed with the current owner.
-- | The body can't write signals: return the setters and write from `Effect`.
createRoot :: forall m a. MonadReactive m => (Effect Unit -> Setup a) -> m a
createRoot = createRootWith {}

type RootOptions =
  ( -- | A stable hydration id prefix for what the root creates.
    id :: String
  -- | Don't count as an owner level for hydration ids.
  , transparent :: Boolean
  )

-- | Takes any subset of `RootOptions`.
createRootWith
  :: forall m a given missing
   . MonadReactive m
  => Row.Union given missing RootOptions
  => { | given }
  -> (Effect Unit -> Setup a)
  -> m a
createRootWith options body =
  liftReactive (runEffectFn2 createRootImpl (mkEffectFn1 (runSetup <<< body)) options)

foreign import createRootImpl :: forall a options. EffectFn2 (EffectFn1 (Effect Unit) a) { | options } a
