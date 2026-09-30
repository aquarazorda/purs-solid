-- | Context: values provided to a subtree. Every context has a default; for one
-- | that must be provided, use `Context (Maybe a)` with default `Nothing`.
module Solid.Context
  ( Context
  , createContext
  , useContext
  , provide
  ) where

import Effect.Uncurried (EffectFn1, runEffectFn1)
import Solid.Internal.Setup (Setup(..), runSetup)
import Data.Function.Uncurried (Fn2, runFn2, runFn3)
import Solid.Internal.View (JSX, provideImpl)

foreign import data Context :: Type -> Type

type role Context nominal

-- | The name identifies the context: every `createContext` with the same name
-- | is the same context (the first default wins), so define it once at the
-- | top level under a qualified name, e.g. `createContext "App.theme" Light`.
-- | It also shows in Solid's dev diagnostics.
createContext :: forall a. String -> a -> Context a
createContext = runFn2 createContextImpl

foreign import createContextImpl :: forall a. Fn2 String a (Context a)

-- | The nearest provided value, or the context's default.
useContext :: forall a. Context a -> Setup a
useContext context = Setup (runEffectFn1 useContextImpl context)

foreign import useContextImpl :: forall a. EffectFn1 (Context a) a

provide :: forall a. Context a -> a -> Setup JSX -> JSX
provide context value children = runFn3 provideImpl context value (runSetup children)
