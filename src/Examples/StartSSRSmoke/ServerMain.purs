module Examples.StartSSRSmoke.ServerMain
  ( renderDocument
  , handleRequest
  , handleRuntimeRequest
  , handleWebRuntimeRequest
  ) where

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits as StringCodeUnits
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Prelude

import Examples.StartSSRSmoke.App as SmokeApp
import Solid.Start.Entry.Server as ServerEntry
import Solid.Start.Error (StartError)
import Solid.Start.Server.API as API
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Solid.Start.Server.Router as Router
import Solid.Start.Server.Runtime as Runtime

renderDocument :: Effect (Either StartError String)
renderDocument =
  ServerEntry.renderDocumentHtml SmokeApp.app

handleRequest :: Request.Request -> Effect (Either StartError Response.Response)
handleRequest request =
  if isApiPath (Request.path request) then
    Router.dispatch apiRouter request
  else
    ServerEntry.renderDocumentResponse 200 SmokeApp.app

handleRuntimeRequest :: Runtime.RuntimeRequest -> Effect Runtime.RuntimeResponse
handleRuntimeRequest =
  Runtime.handleRuntimeRequest handleRequest

handleWebRuntimeRequest :: Runtime.RuntimeRequest -> Aff Runtime.RuntimeResponse
handleWebRuntimeRequest =
  Runtime.handleWebRuntimeRequest (liftEffect <<< handleRequest)

apiRouter :: Router.Router
apiRouter =
  Router.registerRoutes
    [ { path: "/api/health"
      , handler: API.onlyMethod Request.GET \_ ->
          pure (Right (Response.okText "ok"))
      }
    , { path: "/api/stream"
      , handler: API.onlyMethod Request.GET \_ ->
          pure (Right (Response.okStreamText [ "chunk-1", "chunk-2", "chunk-3" ]))
      }
    , { path: "/api/server-function"
      , handler: API.onlyMethod Request.POST serverFunctionHandler
      }
    ]

serverFunctionHandler :: API.ApiHandler
serverFunctionHandler request =
  case Request.body request of
    Just "ping" ->
      pure (Right (Response.okText "pong"))
    _ ->
      pure
        ( Right
            ( Response.withHeader
                "x-start-error-kind"
                "ServerFunctionExecutionError"
                (Response.badRequestText "unexpected payload")
            )
        )

isApiPath :: String -> Boolean
isApiPath path =
  StringCodeUnits.take 5 path == "/api/"
