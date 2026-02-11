module Solid.Start.Routing.Manifest
  ( routes
  , matchPath
  ) where

import Data.Either (Either)

import Solid.Start.Internal.Manifest (allRoutes)
import Solid.Start.Routing (MatchError, RouteDef, RouteMatch, matchPathIn)

routes :: Array RouteDef
routes = allRoutes

matchPath :: String -> Either MatchError RouteMatch
matchPath requestedPath =
  matchPathIn allRoutes requestedPath
