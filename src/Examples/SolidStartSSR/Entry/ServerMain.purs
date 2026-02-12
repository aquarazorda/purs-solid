module Examples.SolidStartSSR.Entry.ServerMain
  ( renderDocumentForRoute
  , handleRequest
  , handleRuntimeRequest
  , prerenderEntries
  , renderPrerenderEntry
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits as StringCodeUnits
import Effect (Effect)

import Examples.SolidStartSSR.App as Example
import Solid.Start.App as StartApp
import Solid.Start.Entry.Server as ServerEntry
import Solid.Start.Error (StartError(..))
import Solid.Start.Meta as Meta
import Solid.Start.Prerender as Prerender
import Solid.Start.Server.API as API
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Solid.Start.Server.Router as Router
import Solid.Start.Server.Runtime as Runtime

renderDocumentForRoute :: String -> Effect (Either StartError String)
renderDocumentForRoute routePath =
  ServerEntry.renderDocumentHtmlWithAssets
    StartApp.defaultStartConfig
    (routeMeta routePath)
    [ "/client.js" ]
    (Example.appWithRoute routePath)

handleRequest :: Request.Request -> Effect (Either StartError Response.Response)
handleRequest request =
  if isApiPath path then
    Router.dispatch apiRouter request
  else if isAppPath path then
    ServerEntry.renderDocumentResponseWithAssets
      200
      StartApp.defaultStartConfig
      (routeMeta appRoute)
      [ "/client.js" ]
      (Example.appWithRoute appRoute)
  else
    pure (Left (RouteNotFound ("No route matched path: " <> path)))
  where
  path = Request.path request
  appRoute = toAppRoute path

handleRuntimeRequest :: Runtime.RuntimeRequest -> Effect Runtime.RuntimeResponse
handleRuntimeRequest =
  Runtime.handleRuntimeRequest handleRequest

prerenderEntries :: Array Prerender.PrerenderEntry
prerenderEntries =
  Prerender.entries
    ( Prerender.fromPaths
        [ Example.basePath <> "/"
        , Example.basePath <> "/stream/"
        , Example.basePath <> "/server-function/"
        ]
    )

renderPrerenderEntry :: Prerender.PrerenderEntry -> Effect (Either StartError String)
renderPrerenderEntry entry =
  renderDocumentForRoute (toAppRoute entry.routePath)

apiRouter :: Router.Router
apiRouter =
  Router.registerRoutes
    [ { path: Example.basePath <> "/api/health"
      , handler: API.onlyMethod Request.GET \_ ->
          pure (Right (Response.okText "ok"))
      }
    , { path: Example.basePath <> "/api/stream"
      , handler: API.onlyMethod Request.GET \_ ->
          pure (Right (Response.okStreamText [ "chunk-1", "chunk-2", "chunk-3" ]))
      }
    , { path: Example.basePath <> "/api/server-function"
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

routeMeta :: String -> Meta.MetaDoc
routeMeta routePath =
  Meta.fromTitle ("purs-solid Start SSR Example - " <> routePath)
    `Meta.merge` Meta.withTag (Meta.MetaNameTag "description" "SolidStart SSR runtime demo") Meta.empty

isApiPath :: String -> Boolean
isApiPath path =
  startsWith (Example.basePath <> "/api/") path

isAppPath :: String -> Boolean
isAppPath path =
  path == Example.basePath || startsWith (Example.basePath <> "/") path

toAppRoute :: String -> String
toAppRoute path =
  normalizeRoute pathWithoutBase
  where
  pathWithoutBase =
    if path == Example.basePath then
      "/"
    else if startsWith (Example.basePath <> "/") path then
      StringCodeUnits.drop (StringCodeUnits.length Example.basePath) path
    else
      path

normalizeRoute :: String -> String
normalizeRoute raw =
  if raw == "" then
    "/"
  else if raw == "/" then
    "/"
  else if StringCodeUnits.takeRight 1 raw == "/" then
    StringCodeUnits.dropRight 1 raw
  else
    raw

startsWith :: String -> String -> Boolean
startsWith prefix value =
  StringCodeUnits.take (StringCodeUnits.length prefix) value == prefix
