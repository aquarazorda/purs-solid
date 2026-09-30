-- | Context: values provided to a subtree. Every context has a default; for one
-- | that must be provided, use `Context (Maybe a)` with default `Nothing`.
module Solid.Context
  ( Context
  , createContext
  , createNamedContext
  , useContext
  , provide
  ) where

import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Solid.Internal.Setup (Setup(..), runSetup)
import Data.Function.Uncurried (runFn3)
import Solid.Internal.View (JSX, provideImpl)

foreign import data Context :: Type -> Type

type role Context nominal

-- | Each call creates a distinct context; for a module-level one, create it
-- | once (e.g. with `unsafePerformEffect`) and share it.
createContext :: forall a. a -> Effect (Context a)
createContext = createNamedContext ""

-- | The name shows in Solid's dev diagnostics.
createNamedContext :: forall a. String -> a -> Effect (Context a)
createNamedContext name defaultValue = runEffectFn2 createContextImpl name defaultValue

foreign import createContextImpl :: forall a. EffectFn2 String a (Context a)

-- | The nearest provided value, or the context's default.
useContext :: forall a. Context a -> Setup a
useContext context = Setup (runEffectFn1 useContextImpl context)

foreign import useContextImpl :: forall a. EffectFn1 (Context a) a

provide :: forall a. Context a -> a -> Setup JSX -> JSX
provide context value children = runFn3 provideImpl context value (runSetup children)
