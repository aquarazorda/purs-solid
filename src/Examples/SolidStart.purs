module Examples.SolidStart where

import Prelude

import Data.Either (Either(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Examples.Counter as Counter
import Examples.TodoMVC as TodoMVC
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM as DOM
import Solid.DOM.Events as Events
import Solid.DOM.HTML as HTML
import Solid.JSX (JSX)
import Solid.Lifecycle (onCleanup, onMount)
import Solid.Reactivity (createEffect, createMemo)
import Solid.Signal (Setter, createSignal, get, set)
import Solid.Start.Client.Navigation as ClientNavigation
import Solid.Start.Error (StartError(..))
import Solid.Start.Internal.Serialization as Serialization
import Solid.Start.Server.Function as ServerFunction
import Solid.Start.Routing.Manifest as StartManifest
import Solid.Web (render, requireBody)

basePath :: String
basePath = "/examples/solid-start"

routeStyles :: Array ClientNavigation.RouteStyle
routeStyles =
  [ { route: "/counter"
    , id: "purs-solid-start-counter-style"
    , href: "/examples/counter/counter.css"
    }
  , { route: "/todomvc"
    , id: "purs-solid-start-todomvc-style"
    , href: "/examples/todomvc/todomvc.css"
    }
  ]

data RouteView
  = HomeView
  | CounterView
  | TodoView
  | ServerFunctionView
  | NotFoundView String

resolveRouteView :: String -> RouteView
resolveRouteView routePath =
  case StartManifest.matchPath routePath of
    Left _ -> NotFoundView routePath
    Right routeMatch ->
      case routeMatch.route.id of
        "/" -> HomeView
        "/counter" -> CounterView
        "/todomvc" -> TodoView
        "/server-function" -> ServerFunctionView
        routeId -> NotFoundView routeId

routeHref :: String -> String
routeHref routeId =
  case routeId of
    "/" -> "/examples/solid-start/"
    "/counter" -> "/examples/solid-start/counter/"
    "/todomvc" -> "/examples/solid-start/todomvc/"
    "/server-function" -> "/examples/solid-start/server-function/"
    _ -> "/examples/solid-start/"

linkClass :: String -> String -> String
linkClass currentRoute routeId =
  if currentRoute == routeId then
    "start-link active"
  else
    "start-link"

navigateToRoute :: String -> Setter String -> (String -> Effect String) -> Effect Unit
navigateToRoute routeId setCurrentRoute navigate = do
  nextRoute <- navigate routeId
  _ <- set setCurrentRoute nextRoute
  pure unit

homeContent :: Setter String -> JSX
homeContent setCurrentRoute =
  HTML.section { className: "start-card" }
    [ HTML.h2_ [ DOM.text "Route navigation demo" ]
    , HTML.p_ [ DOM.text "This SolidStart-style app renders Counter and TodoMVC through one routed PureScript entrypoint." ]
    , HTML.div { className: "start-grid" }
        [ HTML.a
            { className: "start-tile"
            , href: routeHref "/counter"
            , onClick: Events.handler \event ->
                navigateToRoute "/counter" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
            }
            [ HTML.h2_ [ DOM.text "/counter" ]
            , HTML.p_ [ DOM.text "Loads the signal counter app." ]
            ]
        , HTML.a
            { className: "start-tile"
            , href: routeHref "/todomvc"
            , onClick: Events.handler \event ->
                navigateToRoute "/todomvc" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
            }
            [ HTML.h2_ [ DOM.text "/todomvc" ]
            , HTML.p_ [ DOM.text "Loads the TodoMVC app." ]
            ]
        , HTML.a
            { className: "start-tile"
            , href: routeHref "/server-function"
            , onClick: Events.handler \event ->
                navigateToRoute "/server-function" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
            }
            [ HTML.h2_ [ DOM.text "/server-function" ]
            , HTML.p_ [ DOM.text "Runs a server-function transport round-trip demo." ]
            ]
        ]
    ]

notFoundContent :: Setter String -> String -> JSX
notFoundContent setCurrentRoute routePath =
  HTML.section { className: "start-card" }
    [ HTML.h2_ [ DOM.text "Route not found" ]
    , HTML.p_ [ DOM.text ("No route matched: " <> routePath) ]
    , HTML.p_
        [ DOM.text "Go back to "
        , HTML.a
            { href: routeHref "/"
            , onClick: Events.handler \event ->
                navigateToRoute "/" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
            }
            [ DOM.text "home" ]
        , DOM.text "."
        ]
    ]

runServerFunctionDemo :: String -> Setter String -> Effect Unit
runServerFunctionDemo payload setServerResult = do
  let codec = Serialization.mkWireCodec identity Right
  let serverFunction =
        ServerFunction.createServerFunction codec codec \requestPayload ->
          if requestPayload == "ping" then
            pure (Right "pong")
          else
            pure (Left (ServerFunctionExecutionError "unexpected payload"))

  launchAff_ do
    callResult <- ServerFunction.callWithTransportCachedAff
      serverFunction
      "example-server-function"
      { invalidate: \_ -> pure (Right unit)
      , revalidate: \_ -> pure (Right unit)
      }
      (ServerFunction.httpPostTransport "/api/server-function")
      payload
    liftEffect case callResult of
      Left startError -> do
        _ <- set setServerResult ("error: " <> show startError)
        pure unit
      Right value -> do
        _ <- set setServerResult ("ok: " <> value)
        pure unit

serverFunctionContent :: Setter String -> Setter String -> String -> JSX
serverFunctionContent setCurrentRoute setServerResult lastResult =
  HTML.section { className: "start-card" }
    [ HTML.h2_ [ DOM.text "Server function transport demo" ]
    , HTML.p_ [ DOM.text "This route uses callWithTransportCachedAff over HTTP POST with invalidate/revalidate hooks to exercise a real client/server transport path." ]
    , HTML.button
        { className: "start-link"
        , id: "server-fn-success"
        , onClick: Events.handler_ (runServerFunctionDemo "ping" setServerResult)
        }
        [ DOM.text "Run success call" ]
    , HTML.button
        { className: "start-link"
        , id: "server-fn-error"
        , onClick: Events.handler_ (runServerFunctionDemo "boom" setServerResult)
        }
        [ DOM.text "Run error call" ]
    , HTML.p_ [ DOM.text ("Last result: " <> lastResult) ]
    , HTML.p_
        [ DOM.text "Go back to "
        , HTML.a
            { href: routeHref "/"
            , onClick: Events.handler \event ->
                navigateToRoute "/" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
            }
            [ DOM.text "home" ]
        , DOM.text "."
        ]
    ]

routeContent :: Setter String -> JSX -> String -> JSX
routeContent setCurrentRoute serverFunctionNode currentRoute =
  case resolveRouteView currentRoute of
    HomeView -> homeContent setCurrentRoute
    CounterView ->
      HTML.div { className: "start-route-app" }
        [ Component.element Counter.counterApp {}
        ]
    TodoView ->
      HTML.div { className: "start-route-app" }
        [ Component.element TodoMVC.todoApp {}
        ]
    ServerFunctionView -> serverFunctionNode
    NotFoundView routePath -> notFoundContent setCurrentRoute routePath

mkApp :: Effect String -> Component.Component {}
mkApp resolveInitialRoute = Component.component \_ -> do
  initialRoute <- resolveInitialRoute
  currentRoute /\ setCurrentRoute <- createSignal initialRoute
  serverFunctionResult /\ setServerFunctionResult <- createSignal "idle"

  homeLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/")

  counterLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/counter")

  todoLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/todomvc")

  serverFunctionLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/server-function")

  serverFunctionNode <- createMemo do
    result <- get serverFunctionResult
    pure (serverFunctionContent setCurrentRoute setServerFunctionResult result)

  routeNode <- createMemo do
    route <- get currentRoute
    serverFnRouteNode <- get serverFunctionNode
    pure (routeContent setCurrentRoute serverFnRouteNode route)

  _ <- createEffect do
    route <- get currentRoute
    _ <- ClientNavigation.applyRouteStyles routeStyles route
    pure unit

  _ <- onMount do
    unsubscribe <- ClientNavigation.subscribeRouteChanges basePath \nextRoute -> do
      _ <- set setCurrentRoute nextRoute
      pure unit
    _ <- onCleanup unsubscribe
    pure unit

  pure $ HTML.div { className: "start-layout" }
    [ HTML.header { className: "start-nav" }
        [ HTML.h1 { className: "start-brand" } [ DOM.text "purs-solid Start app" ]
        , HTML.nav { className: "start-links" }
            [ HTML.a
                { className: homeLinkClass
                , href: routeHref "/"
                , onClick: Events.handler \event ->
                    navigateToRoute "/" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
                }
                [ DOM.text "Home" ]
            , HTML.a
                { className: counterLinkClass
                , href: routeHref "/counter"
                , onClick: Events.handler \event ->
                    navigateToRoute "/counter" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
                }
                [ DOM.text "Counter" ]
            , HTML.a
                { className: todoLinkClass
                , href: routeHref "/todomvc"
                , onClick: Events.handler \event ->
                    navigateToRoute "/todomvc" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
                }
                [ DOM.text "TodoMVC" ]
            , HTML.a
                { className: serverFunctionLinkClass
                , href: routeHref "/server-function"
                , onClick: Events.handler \event ->
                    navigateToRoute "/server-function" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
                }
                [ DOM.text "ServerFn" ]
            ]
        ]
    , HTML.main { className: "start-main" }
        [ Control.dynamicTag "div"
            { className: "start-route-body"
            , children: routeNode
            }
        ]
    ]

app :: Component.Component {}
app = mkApp (ClientNavigation.startRoutePath basePath)

appWithRoute :: String -> Component.Component {}
appWithRoute routePath = mkApp (pure routePath)

main :: Effect Unit
main = do
  mountResult <- requireBody
  case mountResult of
    Left webError ->
      log ("Mount error: " <> show webError)

    Right mountNode -> do
      renderResult <- render (pure (Component.element app {})) mountNode
      case renderResult of
        Left webError ->
          log ("Render error: " <> show webError)
        Right _dispose ->
          pure unit
