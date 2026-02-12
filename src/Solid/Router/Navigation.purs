module Solid.Router.Navigation
  ( RouteStyle
  , startRoutePath
  , navigateToRoutePath
  , navigateFromClick
  , subscribeRouteChanges
  , applyRouteStyles
  ) where

import Prelude

import Effect (Effect)
import Web.Event.Event (Event)

type RouteStyle =
  { route :: String
  , id :: String
  , href :: String
  }

foreign import startRoutePath :: String -> Effect String

foreign import navigateToRoutePath :: String -> String -> Effect String

foreign import navigateFromClick :: Event -> String -> String -> Effect String

foreign import subscribeRouteChanges :: String -> (String -> Effect Unit) -> Effect (Effect Unit)

foreign import applyRouteStyles :: Array RouteStyle -> String -> Effect Unit
