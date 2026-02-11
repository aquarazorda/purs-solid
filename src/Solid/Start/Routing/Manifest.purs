module Solid.Start.Routing.Manifest
  ( matchPath
  ) where

import Data.Either (Either)

import Solid.Start.Internal.Manifest (allRoutes)
import Solid.Start.Routing (MatchError, RouteMatch, matchPathIn)

matchPath :: String -> Either MatchError RouteMatch
matchPath requestedPath =
  matchPathIn allRoutes requestedPath
