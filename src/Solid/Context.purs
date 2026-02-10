module Solid.Context
  ( Context
  , createContext
  , createContextWithDefault
  , useContext
  , withContext
  ) where

import Data.Maybe (Maybe(..))
import Effect (Effect)

foreign import data Context :: Type -> Type

createContext :: forall a. Effect (Context a)
createContext = createContextImpl Nothing

createContextWithDefault :: forall a. a -> Effect (Context a)
createContextWithDefault defaultValue = createContextImpl (Just defaultValue)

foreign import createContextImpl :: forall a. Maybe a -> Effect (Context a)

foreign import useContext :: forall a. Context a -> Effect (Maybe a)

foreign import withContext :: forall a b. Context a -> a -> Effect b -> Effect b
