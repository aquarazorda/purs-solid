module Solid.Start.Error
  ( StartError(..)
  , fromRouteMiss
  ) where

import Prelude

data StartError
  = RouteNotFound String
  | RouteDecodeError String
  | ServerFunctionDecodeError String
  | ServerFunctionExecutionError String
  | SerializationError String
  | MiddlewareError String
  | SessionError String
  | HydrationError String
  | EnvironmentError String

derive instance eqStartError :: Eq StartError

instance showStartError :: Show StartError where
  show = case _ of
    RouteNotFound message -> "RouteNotFound " <> show message
    RouteDecodeError message -> "RouteDecodeError " <> show message
    ServerFunctionDecodeError message -> "ServerFunctionDecodeError " <> show message
    ServerFunctionExecutionError message -> "ServerFunctionExecutionError " <> show message
    SerializationError message -> "SerializationError " <> show message
    MiddlewareError message -> "MiddlewareError " <> show message
    SessionError message -> "SessionError " <> show message
    HydrationError message -> "HydrationError " <> show message
    EnvironmentError message -> "EnvironmentError " <> show message

fromRouteMiss :: String -> StartError
fromRouteMiss path =
  RouteNotFound ("No route matched path: " <> path)
