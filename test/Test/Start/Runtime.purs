module Test.Start.Runtime
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.Start.Error (StartError(..))
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Solid.Start.Server.Runtime as Runtime
import Test.Assert (assertEqual)

foreign import mkRuntimeRequest
  :: String
  -> String
  -> Array (String /\ String)
  -> Array (String /\ String)
  -> Maybe String
  -> Runtime.RuntimeRequest

foreign import mkWebRuntimeRequest :: Effect Runtime.RuntimeRequest

run :: Effect Unit
run = do
  let runtimeRequest =
        mkRuntimeRequest
          "get"
          "/api/users"
          [ "accept" /\ "application/json" ]
          [ "page" /\ "2" ]
          (Just "{}")

  adapted <- Runtime.adaptRequest runtimeRequest
  case adapted of
    Left startError ->
      throw ("adaptRequest should succeed, got " <> show startError)
    Right request -> do
      assertEqual "runtime method normalization" Request.GET (Request.method request)
      assertEqual "runtime path mapping" "/api/users" (Request.path request)
      assertEqual "runtime header mapping" (Just "application/json") (Request.lookupHeader "accept" request)
      assertEqual "runtime query mapping" (Just "2") (Request.lookupQuery "page" request)
      assertEqual "runtime body mapping" (Just "{}") (Request.body request)

  unsupportedMethod <- Runtime.adaptRequest (mkRuntimeRequest "trace" "/api/users" [] [] Nothing)
  assertEqual
    "unsupported HTTP methods map to EnvironmentError"
    (Left (EnvironmentError "Unsupported HTTP method: TRACE"))
    unsupportedMethod

  let runtimeResponse = Runtime.toRuntimeResponse (Response.json 201 "{\"ok\":true}")
  assertEqual "runtime response status" 201 (Runtime.runtimeResponseStatus runtimeResponse)
  assertEqual "runtime response body kind" "json" (Runtime.runtimeResponseBodyKind runtimeResponse)
  assertEqual "runtime response body" "{\"ok\":true}" (Runtime.runtimeResponseBody runtimeResponse)
  assertEqual "runtime response uses native web Response when available" true (Runtime.runtimeResponseIsWeb runtimeResponse)

  let runtimeStreamResponse = Runtime.toRuntimeResponse (Response.okStreamText [ "hello", "-", "stream" ])
  assertEqual "runtime stream response body kind" "stream" (Runtime.runtimeResponseBodyKind runtimeStreamResponse)
  assertEqual "runtime stream response body text" "hello-stream" (Runtime.runtimeResponseBody runtimeStreamResponse)
  assertEqual "runtime stream response chunks" [ "hello", "-", "stream" ] (Runtime.runtimeResponseStreamChunks runtimeStreamResponse)

  handled <- Runtime.handleRuntimeRequest
    (\request -> pure (Right (Response.text 200 ("hello:" <> Request.path request))))
    runtimeRequest
  assertEqual "runtime handler status" 200 (Runtime.runtimeResponseStatus handled)
  assertEqual "runtime handler body" "hello:/api/users" (Runtime.runtimeResponseBody handled)

  handledError <- Runtime.handleRuntimeRequest
    (\_ -> pure (Left (RouteNotFound "No route matched path: /missing")))
    runtimeRequest
  assertEqual "runtime error mapping status" 404 (Runtime.runtimeResponseStatus handledError)
  assertEqual "runtime error mapping body" "No route matched path: /missing" (Runtime.runtimeResponseBody handledError)

  webRuntimeRequest <- mkWebRuntimeRequest

  launchAff_ do
    adaptedWeb <- Runtime.adaptWebRequest webRuntimeRequest
    liftEffect case adaptedWeb of
      Left startError ->
        throw ("adaptWebRequest should succeed for web Request, got " <> show startError)
      Right request -> do
        assertEqual "web request method mapping" Request.POST (Request.method request)
        assertEqual "web request path mapping" "/api/users" (Request.path request)
        assertEqual "web request header mapping" (Just "token") (Request.lookupHeader "x-auth" request)
        assertEqual "web request query mapping" (Just "3") (Request.lookupQuery "page" request)
        assertEqual "web request body mapping" (Just "{\"ping\":true}") (Request.body request)

    handledWeb <- Runtime.handleWebRuntimeRequest
      (\request -> pure (Right (Response.text 200 ("web:" <> Request.path request))))
      webRuntimeRequest

    liftEffect do
      assertEqual "web runtime handler status" 200 (Runtime.runtimeResponseStatus handledWeb)
      assertEqual "web runtime handler body" "web:/api/users" (Runtime.runtimeResponseBody handledWeb)
