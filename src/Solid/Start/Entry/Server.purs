module Solid.Start.Entry.Server
  ( ServerRequest
  , ServerResponse
  , ServerHandler
  , mkRequest
  , requestPath
  , requestMethod
  , responseStatus
  , responseHeaders
  , responseBody
  , okText
  , notFoundText
  , handleRequest
  ) where

import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested (type (/\))
import Effect (Effect)

import Solid.Start.Error (StartError)
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response

type ServerRequest = Request.Request

type ServerResponse = Response.Response

type ServerHandler = ServerRequest -> Effect (Either StartError ServerResponse)

mkRequest :: Request.Method -> String -> ServerRequest
mkRequest method path =
  Request.mkRequest method path [] [] Nothing

requestPath :: ServerRequest -> String
requestPath = Request.path

requestMethod :: ServerRequest -> Request.Method
requestMethod = Request.method

responseStatus :: ServerResponse -> Int
responseStatus = Response.status

responseHeaders :: ServerResponse -> Array (String /\ String)
responseHeaders = Response.headers

responseBody :: ServerResponse -> Response.ResponseBody
responseBody = Response.body

okText :: String -> ServerResponse
okText = Response.text 200

notFoundText :: String -> ServerResponse
notFoundText = Response.text 404

handleRequest :: ServerHandler -> ServerRequest -> Effect (Either StartError ServerResponse)
handleRequest handler request =
  handler request
