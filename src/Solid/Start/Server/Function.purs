module Solid.Start.Server.Function
  ( ServerFunction
  , CacheKey
  , CacheHooks
  , SerializedTransport
  , SerializedTransportAff
  , createServerFunction
  , cacheKeyValue
  , cacheKeyFor
  , defaultCacheHooks
  , encodeStartErrorWire
  , decodeStartErrorWire
  , call
  , callWithTransport
  , callWithTransportCached
  , callWithTransportAff
  , callWithTransportCachedAff
  , httpPostTransport
  , dispatchSerialized
  ) where

import Control.Promise as Promise
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as StringCodeUnits
import Data.String.Pattern (Pattern(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Prelude

import Solid.Start.Error (StartError(..))
import Solid.Start.Internal.Serialization (WireCodec, decodeWith, encodeWith)

newtype ServerFunction input output = ServerFunction
  { encodeInput :: input -> String
  , decodeInput :: String -> Either String input
  , decodeOutput :: String -> Either String output
  , encodeOutput :: output -> String
  , execute :: input -> Effect (Either StartError output)
  }

type SerializedTransport = String -> Effect (Either StartError String)

type SerializedTransportAff = String -> Aff (Either StartError String)

newtype CacheKey = CacheKey String

derive instance eqCacheKey :: Eq CacheKey

instance showCacheKey :: Show CacheKey where
  show (CacheKey keyValue) = "CacheKey " <> show keyValue

type CacheHooks =
  { invalidate :: CacheKey -> Effect (Either StartError Unit)
  , revalidate :: CacheKey -> Effect (Either StartError Unit)
  }

createServerFunction
  :: forall input output
   . WireCodec input
  -> WireCodec output
  -> (input -> Effect (Either StartError output))
  -> ServerFunction input output
createServerFunction inputCodec outputCodec execute =
  ServerFunction
    { encodeInput: encodeWith inputCodec
    , decodeInput: decodeWith inputCodec
    , decodeOutput: decodeWith outputCodec
    , encodeOutput: encodeWith outputCodec
    , execute
    }

call
  :: forall input output
   . ServerFunction input output
  -> input
  -> Effect (Either StartError output)
call (ServerFunction serverFunction) input =
  serverFunction.execute input

cacheKeyValue :: CacheKey -> String
cacheKeyValue (CacheKey keyValue) = keyValue

cacheKeyFor
  :: forall input output
   . ServerFunction input output
  -> String
  -> input
  -> CacheKey
cacheKeyFor (ServerFunction serverFunction) namespace input =
  CacheKey (normalizeNamespace namespace <> "::" <> serverFunction.encodeInput input)
  where
  normalizeNamespace value =
    if value == "" then
      "server-function"
    else
      value

defaultCacheHooks :: CacheHooks
defaultCacheHooks =
  { invalidate: \_ -> pure (Right unit)
  , revalidate: \_ -> pure (Right unit)
  }

callWithTransport
  :: forall input output
   . ServerFunction input output
  -> SerializedTransport
  -> input
  -> Effect (Either StartError output)
callWithTransport (ServerFunction serverFunction) transport input = do
  serializedOutputResult <- transport (serverFunction.encodeInput input)
  pure case serializedOutputResult of
    Left startError -> Left startError
    Right serializedOutput ->
      case serverFunction.decodeOutput serializedOutput of
        Left decodeError -> Left (SerializationError decodeError)
        Right output -> Right output

callWithTransportCached
  :: forall input output
   . ServerFunction input output
  -> String
  -> CacheHooks
  -> SerializedTransport
  -> input
  -> Effect (Either StartError output)
callWithTransportCached serverFunction namespace hooks transport input = do
  let key = cacheKeyFor serverFunction namespace input
  invalidated <- hooks.invalidate key
  case invalidated of
    Left startError -> pure (Left startError)
    Right _ -> do
      result <- callWithTransport serverFunction transport input
      case result of
        Left startError -> pure (Left startError)
        Right output -> do
          revalidated <- hooks.revalidate key
          pure case revalidated of
            Left startError -> Left startError
            Right _ -> Right output

callWithTransportAff
  :: forall input output
   . ServerFunction input output
  -> SerializedTransportAff
  -> input
  -> Aff (Either StartError output)
callWithTransportAff (ServerFunction serverFunction) transport input = do
  serializedOutputResult <- transport (serverFunction.encodeInput input)
  pure case serializedOutputResult of
    Left startError -> Left startError
    Right serializedOutput ->
      case serverFunction.decodeOutput serializedOutput of
        Left decodeError -> Left (SerializationError decodeError)
        Right output -> Right output

callWithTransportCachedAff
  :: forall input output
   . ServerFunction input output
  -> String
  -> { invalidate :: CacheKey -> Aff (Either StartError Unit)
     , revalidate :: CacheKey -> Aff (Either StartError Unit)
     }
  -> SerializedTransportAff
  -> input
  -> Aff (Either StartError output)
callWithTransportCachedAff serverFunction namespace hooks transport input = do
  let key = cacheKeyFor serverFunction namespace input
  invalidated <- hooks.invalidate key
  case invalidated of
    Left startError -> pure (Left startError)
    Right _ -> do
      result <- callWithTransportAff serverFunction transport input
      case result of
        Left startError -> pure (Left startError)
        Right output -> do
          revalidated <- hooks.revalidate key
          pure case revalidated of
            Left startError -> Left startError
            Right _ -> Right output

httpPostTransport :: String -> SerializedTransportAff
httpPostTransport endpoint payload = do
  result <- Promise.toAffE (httpPostTransportImpl endpoint payload)
  pure case result of
    Left message ->
      case decodeStartErrorWire message of
        Just startError -> Left startError
        Nothing -> Left (EnvironmentError message)
    Right responseBody -> Right responseBody

dispatchSerialized
  :: forall input output
   . ServerFunction input output
  -> String
  -> Effect (Either StartError String)
dispatchSerialized (ServerFunction serverFunction) serializedInput =
  case serverFunction.decodeInput serializedInput of
    Left decodeError ->
      pure (Left (ServerFunctionDecodeError decodeError))
    Right input -> do
      result <- serverFunction.execute input
      pure case result of
        Left startError -> Left startError
        Right output -> Right (serverFunction.encodeOutput output)

foreign import httpPostTransportImpl
  :: String
  -> String
  -> Effect (Promise.Promise (Either String String))

encodeStartErrorWire :: StartError -> String
encodeStartErrorWire startError =
  errorWirePrefix <> startErrorTag startError <> ":" <> startErrorMessage startError

decodeStartErrorWire :: String -> Maybe StartError
decodeStartErrorWire raw =
  if hasPrefix errorWirePrefix raw then
    case Array.uncons segments of
      Nothing -> Nothing
      Just { head: tag, tail: messageSegments } ->
        parseStartErrorTag tag (String.joinWith ":" messageSegments)
  else
    Nothing
  where
  payload = StringCodeUnits.drop (StringCodeUnits.length errorWirePrefix) raw
  segments = String.split (Pattern ":") payload

hasPrefix :: String -> String -> Boolean
hasPrefix prefix value =
  StringCodeUnits.take (StringCodeUnits.length prefix) value == prefix

errorWirePrefix :: String
errorWirePrefix = "START_ERROR:"

startErrorTag :: StartError -> String
startErrorTag = case _ of
  RouteNotFound _ -> "RouteNotFound"
  RouteDecodeError _ -> "RouteDecodeError"
  ServerFunctionDecodeError _ -> "ServerFunctionDecodeError"
  ServerFunctionExecutionError _ -> "ServerFunctionExecutionError"
  SerializationError _ -> "SerializationError"
  MiddlewareError _ -> "MiddlewareError"
  SessionError _ -> "SessionError"
  HydrationError _ -> "HydrationError"
  EnvironmentError _ -> "EnvironmentError"

startErrorMessage :: StartError -> String
startErrorMessage = case _ of
  RouteNotFound message -> message
  RouteDecodeError message -> message
  ServerFunctionDecodeError message -> message
  ServerFunctionExecutionError message -> message
  SerializationError message -> message
  MiddlewareError message -> message
  SessionError message -> message
  HydrationError message -> message
  EnvironmentError message -> message

parseStartErrorTag :: String -> String -> Maybe StartError
parseStartErrorTag tag message =
  case tag of
    "RouteNotFound" -> Just (RouteNotFound message)
    "RouteDecodeError" -> Just (RouteDecodeError message)
    "ServerFunctionDecodeError" -> Just (ServerFunctionDecodeError message)
    "ServerFunctionExecutionError" -> Just (ServerFunctionExecutionError message)
    "SerializationError" -> Just (SerializationError message)
    "MiddlewareError" -> Just (MiddlewareError message)
    "SessionError" -> Just (SessionError message)
    "HydrationError" -> Just (HydrationError message)
    "EnvironmentError" -> Just (EnvironmentError message)
    _ -> Nothing
