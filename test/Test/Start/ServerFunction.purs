module Test.Start.ServerFunction
  ( run
  ) where

import Prelude

import Data.Foldable (for_)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Solid.Start.Error (StartError(..))
import Solid.Start.Internal.Serialization as Serialization
import Solid.Start.Server.Function as ServerFunction
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  let intCodec =
        Serialization.mkWireCodec
          show
          (\raw -> if raw == "41" then Right 41 else Left "expected 41")

  let responseCodec =
        Serialization.mkWireCodec
          identity
          (\raw -> if raw == "42" then Right "42" else Left "expected 42")

  let handler input =
        if input == 41 then
          pure (Right "42")
        else
          pure (Left (ServerFunctionExecutionError "unexpected input"))

  let fn = ServerFunction.createServerFunction intCodec responseCodec handler

  assertEqual
    "cacheKeyFor encodes namespace + input"
    "counter::41"
    (ServerFunction.cacheKeyValue (ServerFunction.cacheKeyFor fn "counter" 41))

  assertEqual
    "cacheKeyFor falls back to default namespace"
    "server-function::41"
    (ServerFunction.cacheKeyValue (ServerFunction.cacheKeyFor fn "" 41))

  for_ errorFixtures \startError -> do
    assertEqual
      ("StartError wire encoding round-trips: " <> show startError)
      (Just startError)
      (ServerFunction.decodeStartErrorWire (ServerFunction.encodeStartErrorWire startError))

  assertEqual
    "decodeStartErrorWire returns Nothing for non-start wire"
    Nothing
    (ServerFunction.decodeStartErrorWire "HTTP 500: boom")

  decoded <- ServerFunction.dispatchSerialized fn "41"
  assertEqual "dispatchSerialized decodes input and encodes output" (Right "42") decoded

  decodeFailure <- ServerFunction.dispatchSerialized fn "0"
  assertEqual
    "dispatchSerialized maps decode errors"
    (Left (ServerFunctionDecodeError "expected 41"))
    decodeFailure

  directCall <- ServerFunction.call fn 41
  assertEqual "direct call executes server function" (Right "42") directCall

  remoteCall <- ServerFunction.callWithTransport fn (ServerFunction.dispatchSerialized fn) 41
  assertEqual "callWithTransport executes round-trip through serialized transport" (Right "42") remoteCall

  failedRemoteCall <- ServerFunction.callWithTransport fn (\_ -> pure (Right "not-a-valid-response")) 41
  assertEqual
    "callWithTransport maps output decode failures to SerializationError"
    (Left (SerializationError "expected 42"))
    failedRemoteCall

  let expectedCacheKey = "counter::41"
  let cacheHooks =
        { invalidate: \cacheKey ->
            if ServerFunction.cacheKeyValue cacheKey == expectedCacheKey then
              pure (Right unit)
            else
              pure (Left (EnvironmentError "unexpected invalidate key"))
        , revalidate: \cacheKey ->
            if ServerFunction.cacheKeyValue cacheKey == expectedCacheKey then
              pure (Right unit)
            else
              pure (Left (EnvironmentError "unexpected revalidate key"))
        }

  cachedCall <- ServerFunction.callWithTransportCached fn "counter" cacheHooks (ServerFunction.dispatchSerialized fn) 41
  assertEqual "callWithTransportCached runs invalidate + revalidate hooks and returns output" (Right "42") cachedCall

  cachedCallDefaultNamespace <- ServerFunction.callWithTransportCached fn "" ServerFunction.defaultCacheHooks (ServerFunction.dispatchSerialized fn) 41
  assertEqual "callWithTransportCached supports default namespace path" (Right "42") cachedCallDefaultNamespace

  cacheInvalidateFailure <- ServerFunction.callWithTransportCached
    fn
    "counter"
    { invalidate: \_ -> pure (Left (MiddlewareError "cache invalidate failed"))
    , revalidate: \_ -> pure (Right unit)
    }
    (ServerFunction.dispatchSerialized fn)
    41
  assertEqual
    "callWithTransportCached maps invalidate hook failures"
    (Left (MiddlewareError "cache invalidate failed"))
    cacheInvalidateFailure

  cacheRevalidateFailure <- ServerFunction.callWithTransportCached
    fn
    "counter"
    { invalidate: \_ -> pure (Right unit)
    , revalidate: \_ -> pure (Left (SessionError "cache revalidate failed"))
    }
    (ServerFunction.dispatchSerialized fn)
    41
  assertEqual
    "callWithTransportCached maps revalidate hook failures"
    (Left (SessionError "cache revalidate failed"))
    cacheRevalidateFailure

  for_ errorFixtures \startError -> do
    propagated <- ServerFunction.callWithTransport fn (\_ -> pure (Left startError)) 41
    assertEqual
      ("callWithTransport propagates StartError variant: " <> show startError)
      (Left startError)
      propagated

  launchAff_ do
    asyncRoundTrip <- ServerFunction.callWithTransportAff fn (\payload -> liftEffect (ServerFunction.dispatchSerialized fn payload)) 41
    liftEffect (assertEqual "callWithTransportAff executes round-trip through transport" (Right "42") asyncRoundTrip)

    asyncDecodeFailure <- ServerFunction.callWithTransportAff fn (\_ -> pure (Right "bad")) 41
    liftEffect
      ( assertEqual
          "callWithTransportAff maps decode failures"
          (Left (SerializationError "expected 42"))
          asyncDecodeFailure
      )

    asyncPropagated <- ServerFunction.callWithTransportAff fn (\_ -> pure (Left (HydrationError "transport hydration error"))) 41
    liftEffect
      ( assertEqual
          "callWithTransportAff propagates StartError variants"
          (Left (HydrationError "transport hydration error"))
          asyncPropagated
      )

    asyncCached <- ServerFunction.callWithTransportCachedAff
      fn
      "counter"
      { invalidate: \_ -> pure (Right unit)
      , revalidate: \_ -> pure (Right unit)
      }
      (\payload -> liftEffect (ServerFunction.dispatchSerialized fn payload))
      41
    liftEffect
      ( assertEqual
          "callWithTransportCachedAff executes invalidate/revalidate around async transport"
          (Right "42")
          asyncCached
      )

    asyncCachedRevalidateFailure <- ServerFunction.callWithTransportCachedAff
      fn
      "counter"
      { invalidate: \_ -> pure (Right unit)
      , revalidate: \_ -> pure (Left (SessionError "async cache revalidate failed"))
      }
      (\payload -> liftEffect (ServerFunction.dispatchSerialized fn payload))
      41
    liftEffect
      ( assertEqual
          "callWithTransportCachedAff maps revalidate failures"
          (Left (SessionError "async cache revalidate failed"))
          asyncCachedRevalidateFailure
      )

errorFixtures :: Array StartError
errorFixtures =
  [ RouteNotFound "route-not-found"
  , RouteDecodeError "route-decode"
  , ServerFunctionDecodeError "server-function-decode"
  , ServerFunctionExecutionError "server-function-exec"
  , SerializationError "serialization"
  , MiddlewareError "middleware"
  , SessionError "session"
  , HydrationError "hydration"
  , EnvironmentError "environment"
  ]
