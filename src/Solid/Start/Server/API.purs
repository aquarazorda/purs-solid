module Solid.Start.Server.API
  ( ApiHandler
  , handle
  , onlyMethod
  ) where

import Data.Either (Either(..))
import Effect (Effect)
import Prelude

import Solid.Start.Error (StartError)
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response

type ApiHandler = Request.Request -> Effect (Either StartError Response.Response)

handle :: ApiHandler -> Request.Request -> Effect (Either StartError Response.Response)
handle handler request =
  handler request

onlyMethod :: Request.Method -> ApiHandler -> ApiHandler
onlyMethod expectedMethod handler request =
  if Request.method request == expectedMethod then
    handler request
  else
    pure (Right (Response.methodNotAllowed expectedMethod))
