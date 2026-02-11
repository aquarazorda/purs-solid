module Test.Start.Router
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Solid.Start.Error (StartError(..))
import Solid.Start.Server.API as API
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Solid.Start.Server.Router as Router
import Test.Assert (assertEqual, expectRight)

run :: Effect Unit
run = do
  let healthHandler = API.onlyMethod Request.GET \_ -> pure (Right (Response.text 200 "ok"))
  let routes =
        [ { path: "/api/health", handler: healthHandler }
        ]
  let router = Router.registerRoutes routes

  ok <- expectRight
    "router dispatches exact path"
    =<< Router.dispatch router (Request.mkRequest Request.GET "/api/health" [] [] Nothing)
  assertEqual "router health status" 200 (Response.status ok)
  assertEqual "router health body" (Response.TextBody "ok") (Response.body ok)

  blocked <- expectRight
    "router preserves method guard behavior"
    =<< Router.dispatch router (Request.mkRequest Request.POST "/api/health" [] [] Nothing)
  assertEqual "router method guard status" 405 (Response.status blocked)

  missing <- Router.dispatch router (Request.mkRequest Request.GET "/api/missing" [] [] Nothing)
  assertEqual
    "router returns RouteNotFound for unknown path"
    (Left (RouteNotFound "No route matched path: /api/missing"))
    missing
