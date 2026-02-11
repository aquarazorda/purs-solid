module Solid.Start.Server.Runtime
  ( RuntimeRequest
  , RuntimeResponse
  , adaptRequest
  , adaptWebRequest
  , toRuntimeResponse
  , handleRuntimeRequest
  , handleWebRuntimeRequest
  , runtimeResponseStatus
  , runtimeResponseHeaders
  , runtimeResponseBody
  , runtimeResponseBodyKind
  , runtimeResponseStreamChunks
  , runtimeResponseIsWeb
  ) where

import Control.Promise as Promise
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
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

foreign import readRuntimeBodyAsync
  :: RuntimeRequest
  -> Effect (Promise.Promise (Maybe String))

foreign import mkRuntimeResponseImpl
  :: Int
  -> Array (String /\ String)
  -> String
  -> String
  -> Array String
  -> RuntimeResponse

foreign import runtimeResponseStatus :: RuntimeResponse -> Int

foreign import runtimeResponseHeaders :: RuntimeResponse -> Array (String /\ String)

foreign import runtimeResponseBody :: RuntimeResponse -> String

foreign import runtimeResponseBodyKind :: RuntimeResponse -> String

foreign import runtimeResponseStreamChunks :: RuntimeResponse -> Array String

foreign import runtimeResponseIsWeb :: RuntimeResponse -> Boolean

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

adaptWebRequest :: RuntimeRequest -> Aff (Either StartError Request.Request)
adaptWebRequest runtimeRequest = do
  methodValue <- liftEffect (readRuntimeMethod runtimeRequest)
  pathValue <- liftEffect (readRuntimePath runtimeRequest)
  headersValue <- liftEffect (readRuntimeHeaders runtimeRequest)
  queryValue <- liftEffect (readRuntimeQuery runtimeRequest)
  bodyValue <- Promise.toAffE (readRuntimeBodyAsync runtimeRequest)
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
    streamChunks
  where
  bodyKind /\ bodyText /\ streamChunks =
    case Response.body response of
      Response.EmptyBody -> "empty" /\ "" /\ []
      Response.TextBody textValue -> "text" /\ textValue /\ []
      Response.JsonBody textValue -> "json" /\ textValue /\ []
      Response.HtmlBody textValue -> "html" /\ textValue /\ []
      Response.StreamBody chunks -> "stream" /\ String.joinWith "" chunks /\ chunks

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

handleWebRuntimeRequest
  :: (Request.Request -> Aff (Either StartError Response.Response))
  -> RuntimeRequest
  -> Aff RuntimeResponse
handleWebRuntimeRequest handler runtimeRequest = do
  adaptedRequest <- adaptWebRequest runtimeRequest
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
  RouteNotFound message -> Response.notFoundText message
  RouteDecodeError message -> Response.badRequestText message
  ServerFunctionDecodeError message -> Response.badRequestText message
  ServerFunctionExecutionError message -> Response.internalServerErrorText message
  SerializationError message -> Response.internalServerErrorText message
  MiddlewareError message -> Response.internalServerErrorText message
  SessionError message -> Response.internalServerErrorText message
  HydrationError message -> Response.internalServerErrorText message
  EnvironmentError message -> Response.internalServerErrorText message
