module Examples.SolidStartSSR.App
  ( basePath
  , app
  , appWithRoute
  ) where

import Prelude

import Data.String.CodeUnits as StringCodeUnits
import Effect (Effect)

import Solid.JSX as JSX
import Solid.Router.Navigation as RouterNavigation
import Solid.Start.App as StartApp

basePath :: String
basePath = ""

data Route
  = OverviewRoute
  | StreamRoute
  | ServerFunctionRoute
  | NotFoundRoute String

normalizeRoutePath :: String -> String
normalizeRoutePath routePath =
  if routePath == "" then
    "/"
  else if routePath == "/" then
    "/"
  else if StringCodeUnits.takeRight 1 routePath == "/" then
    StringCodeUnits.dropRight 1 routePath
  else
    routePath

resolveRoute :: String -> Route
resolveRoute routePath =
  case normalizeRoutePath routePath of
    "/" -> OverviewRoute
    "/stream" -> StreamRoute
    "/server-function" -> ServerFunctionRoute
    path -> NotFoundRoute path

routeDescription :: Route -> String
routeDescription = case _ of
  OverviewRoute ->
    "SolidStart SSR runtime demo (server rendered). Try /stream/ and /server-function/. API endpoints: /api/health, /api/stream, /api/server-function"
  StreamRoute ->
    "Stream route rendered on server. Endpoint: /api/stream"
  ServerFunctionRoute ->
    "Server-function route rendered on server. Endpoint: /api/server-function"
  NotFoundRoute path ->
    "Route not found: " <> path

mkApp :: Effect String -> StartApp.App
mkApp resolveInitialRoute =
  StartApp.createApp do
    routePath <- resolveInitialRoute
    pure (JSX.text (routeDescription (resolveRoute routePath)))

app :: StartApp.App
app = mkApp (RouterNavigation.startRoutePath basePath)

appWithRoute :: String -> StartApp.App
appWithRoute routePath = mkApp (pure routePath)
