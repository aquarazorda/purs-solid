module Solid.Start.Middleware
  ( Next
  , Middleware
  , run
  , appendResponseHeader
  , requireHeader
  ) where

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Prelude

import Solid.Start.Error (StartError(..))
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response

type Next = Request.Request -> Effect (Either StartError Response.Response)

type Middleware =
  Request.Request
  -> Next
  -> Effect (Either StartError Response.Response)

run :: Array Middleware -> Next -> Next
run middlewares finalNext =
  case Array.uncons middlewares of
    Nothing -> finalNext
    Just { head: middleware, tail: remaining } ->
      \request -> middleware request (run remaining finalNext)

appendResponseHeader :: String -> String -> Middleware
appendResponseHeader key value request next = do
  result <- next request
  pure case result of
    Left startError -> Left startError
    Right response -> Right (Response.withHeader key value response)

requireHeader :: String -> Middleware
requireHeader key request next =
  case Request.lookupHeader key request of
    Just _ -> next request
    Nothing ->
      pure (Left (MiddlewareError ("Missing required header: " <> key)))
