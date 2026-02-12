module Solid.Router.Routing.Manifest
  ( routes
  , matchPath
  ) where

import Data.Either (Either)

import Solid.Router.Internal.Manifest (allRoutes)
import Solid.Router.Routing (MatchError, RouteDef, RouteMatch, matchPathIn)

routes :: Array RouteDef
routes = allRoutes

matchPath :: String -> Either MatchError RouteMatch
matchPath requestedPath =
  matchPathIn allRoutes requestedPath
