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
  case Array.find (\route -> route.path == Request.path request) routes of
    Nothing -> pure (Left (fromRouteMiss (Request.path request)))
    Just route -> route.handler request
