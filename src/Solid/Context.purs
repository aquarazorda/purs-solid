module Solid.Context
  ( Context
  , createContext
  , createContextWithDefault
  , useContext
  , withContext
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, runEffectFn1)

foreign import data Context :: Type -> Type

foreign import createContextImpl :: forall a. Effect (Context a)

createContext :: forall a. Effect (Context a)
createContext = createContextImpl

foreign import createContextWithDefaultImpl :: forall a. EffectFn1 a (Context a)

createContextWithDefault :: forall a. a -> Effect (Context a)
createContextWithDefault = runEffectFn1 createContextWithDefaultImpl

foreign import useContextImpl :: forall a. EffectFn1 (Context a) (Nullable a)

useContext :: forall a. Context a -> Effect (Maybe a)
useContext context = toMaybe <$> runEffectFn1 useContextImpl context

foreign import withContext :: forall a b. Context a -> a -> Effect b -> Effect b
