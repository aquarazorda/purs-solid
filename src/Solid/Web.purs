module Solid.Web
  ( Mountable
  , isServer
  , render
  , hydrate
  , documentBody
  , mountById
  ) where

import Data.Maybe (Maybe)
import Effect (Effect)
import Prelude (Unit)

foreign import data Mountable :: Type

foreign import isServer :: Boolean

foreign import render :: forall a. Effect a -> Mountable -> Effect (Effect Unit)

foreign import hydrate :: forall a. Effect a -> Mountable -> Effect (Effect Unit)

foreign import documentBody :: Effect (Maybe Mountable)

foreign import mountById :: String -> Effect (Maybe Mountable)
