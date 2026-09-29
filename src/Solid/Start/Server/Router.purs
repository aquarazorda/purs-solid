module Solid.Start.Server.Router
  ( ApiRoute
  , Router
  , registerRoutes
  , appendRoute
  , dispatch
  ) where

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as StringCodeUnits
import Data.String.Pattern (Pattern(..))
import Effect (Effect)
import Prelude

import Solid.Start.Error (StartError, fromRouteMiss)
import Solid.Start.Server.API (ApiHandler)
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response

type ApiRoute =
  { path :: String
  , handler :: ApiHandler
  }

newtype Router = Router (Array ApiRoute)

registerRoutes :: Array ApiRoute -> Router
registerRoutes routes = Router routes

appendRoute :: ApiRoute -> Router -> Router
appendRoute route (Router routes) =
  Router (routes <> [ route ])

dispatch :: Router -> Request.Request -> Effect (Either StartError Response.Response)
dispatch (Router routes) request =
  case Array.find (\route -> normalizeRoutePath route.path == requestPath) routes of
    Nothing -> pure (Left (fromRouteMiss requestPath))
    Just route -> route.handler request
  where
  requestPath = normalizeRoutePath (Request.path request)

normalizeRoutePath :: String -> String
normalizeRoutePath rawPath =
  if normalized == "" then
    "/"
  else
    normalized
  where
  pathWithoutQuery =
    takeBefore (Pattern "?") (takeBefore (Pattern "#") rawPath)

  withLeadingSlash =
    if StringCodeUnits.take 1 pathWithoutQuery == "/" then
      pathWithoutQuery
    else
      "/" <> pathWithoutQuery

  normalized =
    trimTrailingSlash withLeadingSlash

trimTrailingSlash :: String -> String
trimTrailingSlash value
  | value == "/" = "/"
  | StringCodeUnits.takeRight 1 value == "/" = trimTrailingSlash (StringCodeUnits.dropRight 1 value)
  | otherwise = value

takeBefore :: Pattern -> String -> String
takeBefore delimiter value =
  case Array.uncons (String.split delimiter value) of
    Nothing -> value
    Just { head: first } -> first
