module Solid.Start.Server.Runtime
  ( RuntimeRequest
  , RuntimeResponse
  , adaptRequest
  , toRuntimeResponse
  , handleRuntimeRequest
  , runtimeResponseStatus
  , runtimeResponseHeaders
  , runtimeResponseBody
  , runtimeResponseBodyKind
  ) where

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Prelude

import Solid.Start.Error (StartError(..))
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response

foreign import data RuntimeRequest :: Type

foreign import data RuntimeResponse :: Type

foreign import readRuntimeMethod :: RuntimeRequest -> Effect String

foreign import readRuntimePath :: RuntimeRequest -> Effect String

foreign import readRuntimeHeaders :: RuntimeRequest -> Effect (Array (String /\ String))

foreign import readRuntimeQuery :: RuntimeRequest -> Effect (Array (String /\ String))

foreign import readRuntimeBody :: RuntimeRequest -> Effect (Maybe String)

foreign import mkRuntimeResponseImpl
  :: Int
  -> Array (String /\ String)
  -> String
  -> String
  -> RuntimeResponse

foreign import runtimeResponseStatus :: RuntimeResponse -> Int

foreign import runtimeResponseHeaders :: RuntimeResponse -> Array (String /\ String)

foreign import runtimeResponseBody :: RuntimeResponse -> String

foreign import runtimeResponseBodyKind :: RuntimeResponse -> String

adaptRequest :: RuntimeRequest -> Effect (Either StartError Request.Request)
adaptRequest runtimeRequest = do
  methodValue <- readRuntimeMethod runtimeRequest
  pathValue <- readRuntimePath runtimeRequest
  headersValue <- readRuntimeHeaders runtimeRequest
  queryValue <- readRuntimeQuery runtimeRequest
  bodyValue <- readRuntimeBody runtimeRequest
  pure case Request.parseMethod methodValue of
    Nothing -> Left (EnvironmentError ("Unsupported HTTP method: " <> methodValue))
    Just method ->
      Right (Request.mkRequest method pathValue headersValue queryValue bodyValue)

toRuntimeResponse :: Response.Response -> RuntimeResponse
toRuntimeResponse response =
  mkRuntimeResponseImpl
    (Response.status response)
    (Response.headers response)
    bodyKind
    bodyText
  where
  bodyKind /\ bodyText =
    case Response.body response of
      Response.EmptyBody -> "empty" /\ ""
      Response.TextBody textValue -> "text" /\ textValue
      Response.JsonBody textValue -> "json" /\ textValue
      Response.HtmlBody textValue -> "html" /\ textValue

handleRuntimeRequest
  :: (Request.Request -> Effect (Either StartError Response.Response))
  -> RuntimeRequest
  -> Effect RuntimeResponse
handleRuntimeRequest handler runtimeRequest = do
  adaptedRequest <- adaptRequest runtimeRequest
  case adaptedRequest of
    Left startError ->
      pure (toRuntimeResponse (errorResponse startError))
    Right typedRequest -> do
      result <- handler typedRequest
      pure case result of
        Left startError -> toRuntimeResponse (errorResponse startError)
        Right response -> toRuntimeResponse response

errorResponse :: StartError -> Response.Response
errorResponse = case _ of
  RouteNotFound message -> Response.text 404 message
  RouteDecodeError message -> Response.text 400 message
  ServerFunctionDecodeError message -> Response.text 400 message
  ServerFunctionExecutionError message -> Response.text 500 message
  SerializationError message -> Response.text 500 message
  MiddlewareError message -> Response.text 500 message
  SessionError message -> Response.text 500 message
  HydrationError message -> Response.text 500 message
  EnvironmentError message -> Response.text 500 message
