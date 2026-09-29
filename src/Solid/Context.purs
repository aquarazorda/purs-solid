-- | Context: values provided to a subtree.
-- |
-- | Every context has a default, so `useContext` is total: it returns the
-- | nearest provided value, or the default outside any provider. For a context
-- | that must be provided, use `Context (Maybe a)` with default `Nothing`.
module Solid.Context
  ( Context
  , createContext
  , useContext
  , provide
  ) where

import Effect (Effect)
import Effect.Uncurried (EffectFn1, runEffectFn1)
import Solid.Internal.Setup (Setup(..), runSetup)
import Data.Function.Uncurried (runFn3)
import Solid.Internal.View (JSX, provideImpl)

foreign import data Context :: Type -> Type

type role Context nominal

-- | Creates a context with a default value. Each call creates a distinct
-- | context. For a module-level context, create it once (e.g. with
-- | `unsafePerformEffect`) and share it.
createContext :: forall a. a -> Effect (Context a)
createContext defaultValue = runEffectFn1 createContextImpl defaultValue

foreign import createContextImpl :: forall a. EffectFn1 a (Context a)

-- | The nearest provided value, or the context's default.
useContext :: forall a. Context a -> Setup a
useContext context = Setup (runEffectFn1 useContextImpl context)

foreign import useContextImpl :: forall a. EffectFn1 (Context a) a

-- | Provides `value` to `children`. The children are `Setup` so they run
-- | inside the provider, where `useContext` sees the value.
provide :: forall a. Context a -> a -> Setup JSX -> JSX
provide context value children = runFn3 provideImpl context value (runSetup children)
