module Examples.SolidStart where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe)
import Data.String.CodeUnits as StringCodeUnits
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Examples.Counter as Counter
import Examples.SolidStart.HackerNews.Api as HackerNews
import Examples.TodoMVC as TodoMVC
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM as DOM
import Solid.DOM.Events as Events
import Solid.DOM.HTML as HTML
import Solid.JSX (JSX)
import Solid.Lifecycle (onCleanup, onMount)
import Solid.Reactivity (createEffect, createMemo)
import Solid.Signal (Setter, createSignal, get, modify, set)
import Solid.Start.Client.Navigation as ClientNavigation
import Solid.Start.Error (StartError(..))
import Solid.Start.Internal.Serialization as Serialization
import Solid.Start.Route.Params as RouteParams
import Solid.Start.Server.Function as ServerFunction
import Solid.Start.Routing.Manifest as StartManifest
import Solid.Web as Web

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

type HnStoriesState =
  { loading :: Boolean
  , error :: Maybe String
  , items :: Array HackerNews.Story
  , feed :: HackerNews.FeedType
  , page :: Int
  }

type HnStoryState =
  { loading :: Boolean
  , error :: Maybe String
  , item :: Maybe HackerNews.StoryDetail
  , storyId :: Maybe String
  }

type HnUserState =
  { loading :: Boolean
  , error :: Maybe String
  , user :: Maybe HackerNews.User
  , userId :: Maybe String
  }

initialHnStoriesState :: HnStoriesState
initialHnStoriesState =
  { loading: false
  , error: Nothing
  , items: []
  , feed: HackerNews.TopFeed
  , page: 1
  }

initialHnStoryState :: HnStoryState
initialHnStoryState =
  { loading: false
  , error: Nothing
  , item: Nothing
  , storyId: Nothing
  }

initialHnUserState :: HnUserState
initialHnUserState =
  { loading: false
  , error: Nothing
  , user: Nothing
  , userId: Nothing
  }

data HnRoute
  = HnFeedRoute HackerNews.FeedType
  | HnStoryRoute String
  | HnUserRoute String

data RouteView
  = HomeView
  | CounterView
  | TodoView
  | ServerFunctionView
  | HackerNewsView HnRoute
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
        "/hn" -> HackerNewsView (HnFeedRoute HackerNews.TopFeed)
        "/hn/new" -> HackerNewsView (HnFeedRoute HackerNews.NewFeed)
        "/hn/show" -> HackerNewsView (HnFeedRoute HackerNews.ShowFeed)
        "/hn/ask" -> HackerNewsView (HnFeedRoute HackerNews.AskFeed)
        "/hn/job" -> HackerNewsView (HnFeedRoute HackerNews.JobFeed)
        "/hn/stories/:id" ->
          case RouteParams.lookupParam "id" routeMatch.params of
            Just storyId -> HackerNewsView (HnStoryRoute storyId)
            Nothing -> NotFoundView routePath
        "/hn/users/:id" ->
          case RouteParams.lookupParam "id" routeMatch.params of
            Just userId -> HackerNewsView (HnUserRoute userId)
            Nothing -> NotFoundView routePath
        routeId -> NotFoundView routeId

routeHref :: String -> String
routeHref routePath =
  if routePath == "/" then
    basePath <> "/"
  else
    basePath <> routePath <> "/"

startsWith :: String -> String -> Boolean
startsWith prefix value =
  StringCodeUnits.take (StringCodeUnits.length prefix) value == prefix

linkClass :: String -> String -> String
linkClass currentRoute routeId =
  if isActiveRoute then
    "start-link active"
  else
    "start-link"
  where
  isActiveRoute =
    if routeId == "/hn" then
      startsWith "/hn" currentRoute
    else
      currentRoute == routeId

navigateToRoute :: String -> Setter String -> (String -> Effect String) -> Effect Unit
navigateToRoute routeId setCurrentRoute navigate = do
  nextRoute <- navigate routeId
  _ <- set setCurrentRoute nextRoute
  pure unit

homeContent :: Setter String -> Setter Int -> JSX
homeContent setCurrentRoute setHnPage =
  HTML.section { className: "start-card" }
    [ HTML.h2_ [ DOM.text "Route navigation demo" ]
    , HTML.p_ [ DOM.text "This SolidStart-style app renders multiple examples, including a Solid Hacker News port, from one routed PureScript entrypoint." ]
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
        , HTML.a
            { className: "start-tile"
            , href: routeHref "/hn"
            , onClick: Events.handler \event -> do
                _ <- set setHnPage 1
                navigateToRoute "/hn" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
            }
            [ HTML.h2_ [ DOM.text "/hn" ]
            , HTML.p_ [ DOM.text "Browses live Hacker News feeds, stories, users, and comment threads." ]
            ]
        ]
    ]

storyRoutePath :: Int -> String
storyRoutePath storyId =
  "/hn/stories/" <> show storyId

userRoutePath :: String -> String
userRoutePath userId =
  "/hn/users/" <> userId

commentsLabel :: Int -> String
commentsLabel count =
  if count == 0 then
    "discuss"
  else
    show count <> " comments"

feedTabClass :: HackerNews.FeedType -> HackerNews.FeedType -> String
feedTabClass activeFeed feed =
  if activeFeed == feed then
    "hn-feed-link active"
  else
    "hn-feed-link"

isExternalStoryUrl :: String -> Boolean
isExternalStoryUrl url =
  not (startsWith "item?id=" url)

renderHnStoryListItem :: Setter String -> HackerNews.Story -> JSX
renderHnStoryListItem setCurrentRoute story =
  HTML.li { className: "hn-story" }
    ( [ HTML.span { className: "hn-story-score" } [ DOM.text (maybe "-" show story.points) ]
      , HTML.div { className: "hn-story-main" }
          [ HTML.p { className: "hn-story-title" }
              ( [ titleNode ] <> hostNode
              )
          , HTML.p { className: "hn-story-meta" }
              [ DOM.text "by "
              , userNode
              , DOM.text " "
              , DOM.text story.timeAgo
              , DOM.text " | "
              , commentsNode
              ]
          ]
      ]
        <> storyTypeNode
    )
  where
  path = storyRoutePath story.id

  titleNode =
    case story.url of
      Just url
        | isExternalStoryUrl url ->
            HTML.a
              { className: "hn-story-title-link"
              , href: url
              , target: "_blank"
              , rel: "noreferrer"
              }
              [ DOM.text story.title ]
      _ ->
        HTML.a
          { className: "hn-story-title-link"
          , href: routeHref path
          , onClick: Events.handler \event ->
              navigateToRoute path setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
          }
          [ DOM.text story.title ]

  hostNode =
    case story.domain of
      Just domainName ->
        [ HTML.span { className: "hn-story-host" } [ DOM.text ("(" <> domainName <> ")") ] ]
      Nothing ->
        []

  userNode =
    case story.user of
      Just userId ->
        HTML.a
          { href: routeHref (userRoutePath userId)
          , onClick: Events.handler \event ->
              navigateToRoute (userRoutePath userId) setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
          }
          [ DOM.text userId ]
      Nothing ->
        HTML.span { className: "hn-story-anon" } [ DOM.text "anonymous" ]

  commentsNode =
    HTML.a
      { href: routeHref path
      , onClick: Events.handler \event ->
          navigateToRoute path setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
      }
      [ DOM.text (commentsLabel story.commentsCount) ]

  storyTypeNode =
    if story.storyType == "link" then
      []
    else
      [ HTML.span { className: "hn-story-type" } [ DOM.text story.storyType ] ]

renderHnComment :: Setter String -> HackerNews.Comment -> JSX
renderHnComment setCurrentRoute (HackerNews.Comment comment) =
  HTML.li { className: "hn-comment" }
    ( [ HTML.p { className: "hn-comment-meta" }
          [ userNode
          , DOM.text " "
          , DOM.text comment.timeAgo
          ]
      , HTML.div
          { className: "hn-comment-body"
          , innerHTML: comment.content
          }
          []
      ]
        <> childNode
    )
  where
  userNode =
    case comment.user of
      Just userId ->
        HTML.a
          { href: routeHref (userRoutePath userId)
          , onClick: Events.handler \event ->
              navigateToRoute (userRoutePath userId) setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
          }
          [ DOM.text userId ]
      Nothing ->
        HTML.span_ [ DOM.text "anonymous" ]

  childNode =
    if Array.null comment.comments then
      []
    else
      [ HTML.ul { className: "hn-comment-children" }
          (map (renderHnComment setCurrentRoute) comment.comments)
      ]

hackerNewsFeedContent :: Setter String -> Setter Int -> HnStoriesState -> HackerNews.FeedType -> JSX
hackerNewsFeedContent setCurrentRoute setHnPage storiesState activeFeed =
  HTML.section { className: "hn-shell" }
    ( [ HTML.header { className: "hn-header" }
          [ HTML.h2_ [ DOM.text "Solid Hacker News" ]
          , HTML.p_ [ DOM.text "A PureScript SolidStart route using live Hacker News APIs." ]
          ]
      , HTML.nav { className: "hn-feed-nav" } (map renderFeedLink allFeeds)
      , HTML.div { className: "hn-pagination" }
          [ HTML.button
              { className: "hn-page-btn"
              , disabled: storiesState.page <= 1 || storiesState.loading
              , onClick: Events.handler_ do
                  if storiesState.page > 1 then do
                    _ <- set setHnPage (storiesState.page - 1)
                    pure unit
                  else
                    pure unit
              }
              [ DOM.text "< prev" ]
          , HTML.span { className: "hn-page-label" } [ DOM.text ("page " <> show storiesState.page) ]
          , HTML.button
              { className: "hn-page-btn"
              , disabled: storiesState.loading
              , onClick: Events.handler_ do
                  _ <- set setHnPage (storiesState.page + 1)
                  pure unit
              }
              [ DOM.text "more >" ]
          ]
      ]
        <> statusNode
        <> loadingNode
        <> listNode
    )
  where
  allFeeds =
    [ HackerNews.TopFeed
    , HackerNews.NewFeed
    , HackerNews.ShowFeed
    , HackerNews.AskFeed
    , HackerNews.JobFeed
    ]

  renderFeedLink feed =
    HTML.a
      { className: feedTabClass activeFeed feed
      , href: routeHref (HackerNews.feedRoutePath feed)
      , onClick: Events.handler \event -> do
          _ <- set setHnPage 1
          navigateToRoute (HackerNews.feedRoutePath feed) setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
      }
      [ DOM.text (HackerNews.feedLabel feed) ]

  statusNode =
    case storiesState.error of
      Just message ->
        [ HTML.p { className: "hn-error" } [ DOM.text ("Could not load stories: " <> message) ] ]
      Nothing ->
        []

  loadingNode =
    if storiesState.loading then
      [ HTML.p { className: "hn-loading" } [ DOM.text "Loading stories..." ] ]
    else
      []

  listNode =
    if Array.null storiesState.items then
      if storiesState.loading then
        []
      else
        [ HTML.p { className: "hn-empty" } [ DOM.text "No stories found." ] ]
    else
      [ HTML.ol { className: "hn-story-list" }
          (map (renderHnStoryListItem setCurrentRoute) storiesState.items)
      ]

hackerNewsStoryContent :: Setter String -> HnStoryState -> String -> JSX
hackerNewsStoryContent setCurrentRoute storyState storyId =
  case storyState.error of
    Just message ->
      HTML.section { className: "hn-shell" }
        [ HTML.p { className: "hn-error" } [ DOM.text ("Could not load story " <> storyId <> ": " <> message) ]
        ]

    Nothing ->
      case storyState.item of
        Nothing ->
          if storyState.loading then
            HTML.section { className: "hn-shell" }
              [ HTML.p { className: "hn-loading" } [ DOM.text ("Loading story " <> storyId <> "...") ]
              ]
          else
            HTML.section { className: "hn-shell" }
              [ HTML.p { className: "hn-empty" } [ DOM.text "Story not found." ]
              ]

        Just story ->
          HTML.section { className: "hn-shell" }
            [ HTML.p { className: "hn-back-link" }
                [ HTML.a
                    { href: routeHref "/hn"
                    , onClick: Events.handler \event ->
                        navigateToRoute "/hn" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
                    }
                    [ DOM.text "<- back to feed" ]
                ]
            , HTML.header { className: "hn-story-detail-head" }
                ( [ storyTitleNode
                  ]
                    <> storyHostNode
                    <> [ HTML.p { className: "hn-story-detail-meta" }
                           [ DOM.text (maybe "-" show story.points)
                           , DOM.text " points | by "
                           , storyUserNode
                           , DOM.text " "
                           , DOM.text story.timeAgo
                           ]
                       ]
                )
            , HTML.section { className: "hn-comments" }
                [ HTML.h3_ [ DOM.text (commentsLabel story.commentsCount) ]
                , if Array.null story.comments then
                    HTML.p { className: "hn-empty" } [ DOM.text "No comments yet." ]
                  else
                    HTML.ul { className: "hn-comment-children" }
                      (map (renderHnComment setCurrentRoute) story.comments)
                ]
            ]
          where
          storyTitleNode =
            case story.url of
              Just url
                | isExternalStoryUrl url ->
                    HTML.a
                      { className: "hn-story-detail-title"
                      , href: url
                      , target: "_blank"
                      , rel: "noreferrer"
                      }
                      [ HTML.h2_ [ DOM.text story.title ] ]
              _ ->
                HTML.h2 { className: "hn-story-detail-title" } [ DOM.text story.title ]

          storyHostNode =
            case story.domain of
              Just domainName ->
                [ HTML.p { className: "hn-story-host" } [ DOM.text ("(" <> domainName <> ")") ] ]
              Nothing ->
                []

          storyUserNode =
            case story.user of
              Just userId ->
                HTML.a
                  { href: routeHref (userRoutePath userId)
                  , onClick: Events.handler \event ->
                      navigateToRoute (userRoutePath userId) setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
                  }
                  [ DOM.text userId ]
              Nothing ->
                HTML.span_ [ DOM.text "anonymous" ]

hackerNewsUserContent :: HnUserState -> String -> JSX
hackerNewsUserContent userState requestedUserId =
  case userState.error of
    Just message ->
      HTML.section { className: "hn-shell" }
        [ HTML.p { className: "hn-error" } [ DOM.text ("Could not load user " <> requestedUserId <> ": " <> message) ]
        ]

    Nothing ->
      case userState.user of
        Nothing ->
          if userState.loading then
            HTML.section { className: "hn-shell" }
              [ HTML.p { className: "hn-loading" } [ DOM.text ("Loading user " <> requestedUserId <> "...") ]
              ]
          else
            HTML.section { className: "hn-shell" }
              [ HTML.p { className: "hn-empty" } [ DOM.text "User not found." ]
              ]

        Just user ->
          HTML.section { className: "hn-shell" }
            [ HTML.header { className: "hn-user-header" }
                [ HTML.h2_ [ DOM.text ("User: " <> user.id) ]
                ]
            , HTML.ul { className: "hn-user-meta" }
                ( [ HTML.li_ [ DOM.text ("Created: " <> user.createdLabel) ]
                  , HTML.li_ [ DOM.text ("Karma: " <> show user.karma) ]
                  ]
                    <> aboutNode
                )
            , HTML.p { className: "hn-user-links" }
                [ HTML.a
                    { href: "https://news.ycombinator.com/submitted?id=" <> user.id
                    , target: "_blank"
                    , rel: "noreferrer"
                    }
                    [ DOM.text "submissions" ]
                , DOM.text " | "
                , HTML.a
                    { href: "https://news.ycombinator.com/threads?id=" <> user.id
                    , target: "_blank"
                    , rel: "noreferrer"
                    }
                    [ DOM.text "comments" ]
                ]
            ]
          where
          aboutNode =
            case user.about of
              Just aboutHtml ->
                [ HTML.li
                    { className: "hn-user-about"
                    , innerHTML: aboutHtml
                    }
                    []
                ]
              Nothing ->
                []

hackerNewsContent
  :: Setter String
  -> Setter Int
  -> HnStoriesState
  -> HnStoryState
  -> HnUserState
  -> HnRoute
  -> JSX
hackerNewsContent setCurrentRoute setHnPage storiesState storyState userState hnRoute =
  case hnRoute of
    HnFeedRoute feed ->
      hackerNewsFeedContent setCurrentRoute setHnPage storiesState feed

    HnStoryRoute storyId ->
      hackerNewsStoryContent setCurrentRoute storyState storyId

    HnUserRoute userId ->
      hackerNewsUserContent userState userId

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

routeContent
  :: Setter String
  -> Setter Int
  -> JSX
  -> HnStoriesState
  -> HnStoryState
  -> HnUserState
  -> RouteView
  -> JSX
routeContent setCurrentRoute setHnPage serverFunctionNode storiesState storyState userState route =
  case route of
    HomeView -> homeContent setCurrentRoute setHnPage
    CounterView ->
      HTML.div { className: "start-route-app" }
        [ Component.element Counter.counterApp {}
        ]
    TodoView ->
      HTML.div { className: "start-route-app" }
        [ Component.element TodoMVC.todoApp {}
        ]
    ServerFunctionView -> serverFunctionNode
    HackerNewsView hnRoute ->
      hackerNewsContent setCurrentRoute setHnPage storiesState storyState userState hnRoute
    NotFoundView routePath -> notFoundContent setCurrentRoute routePath

mkApp :: Effect String -> Component.Component {}
mkApp resolveInitialRoute = Component.component \_ -> do
  initialRoute <- resolveInitialRoute
  currentRoute /\ setCurrentRoute <- createSignal initialRoute
  serverFunctionResult /\ setServerFunctionResult <- createSignal "idle"
  hnPage /\ setHnPage <- createSignal 1
  hnStoriesState /\ setHnStoriesState <- createSignal initialHnStoriesState
  hnStoryState /\ setHnStoryState <- createSignal initialHnStoryState
  hnUserState /\ setHnUserState <- createSignal initialHnUserState
  hnStoriesToken /\ setHnStoriesToken <- createSignal 0
  hnStoryToken /\ setHnStoryToken <- createSignal 0
  hnUserToken /\ setHnUserToken <- createSignal 0

  resolvedRoute <- createMemo do
    route <- get currentRoute
    pure (resolveRouteView route)

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

  hackerNewsLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/hn")

  hnFeedRequest <- createMemo do
    route <- get resolvedRoute
    page <- get hnPage
    pure case route of
      HackerNewsView (HnFeedRoute feed) ->
        Just { feed, page }
      _ ->
        Nothing

  hnStoryRequest <- createMemo do
    route <- get resolvedRoute
    pure case route of
      HackerNewsView (HnStoryRoute storyId) -> Just storyId
      _ -> Nothing

  hnUserRequest <- createMemo do
    route <- get resolvedRoute
    pure case route of
      HackerNewsView (HnUserRoute userId) -> Just userId
      _ -> Nothing

  _ <- createEffect do
    request <- get hnFeedRequest
    case request of
      Nothing -> pure unit
      Just { feed, page } -> do
        requestToken <- modify setHnStoriesToken (_ + 1)
        _ <- set setHnStoriesState
          { loading: true
          , error: Nothing
          , items: []
          , feed
          , page
          }
        launchAff_ do
          result <- HackerNews.fetchStories feed page
          liftEffect do
            latestToken <- get hnStoriesToken
            if latestToken == requestToken then
              case result of
                Left message -> do
                  _ <- set setHnStoriesState
                    { loading: false
                    , error: Just message
                    , items: []
                    , feed
                    , page
                    }
                  pure unit
                Right stories -> do
                  _ <- set setHnStoriesState
                    { loading: false
                    , error: Nothing
                    , items: stories
                    , feed
                    , page
                    }
                  pure unit
            else
              pure unit

  _ <- createEffect do
    maybeStoryId <- get hnStoryRequest
    case maybeStoryId of
      Nothing -> pure unit
      Just storyId -> do
        requestToken <- modify setHnStoryToken (_ + 1)
        _ <- set setHnStoryState
          { loading: true
          , error: Nothing
          , item: Nothing
          , storyId: Just storyId
          }
        launchAff_ do
          result <- HackerNews.fetchStory storyId
          liftEffect do
            latestToken <- get hnStoryToken
            if latestToken == requestToken then
              case result of
                Left message -> do
                  _ <- set setHnStoryState
                    { loading: false
                    , error: Just message
                    , item: Nothing
                    , storyId: Just storyId
                    }
                  pure unit
                Right story -> do
                  _ <- set setHnStoryState
                    { loading: false
                    , error: Nothing
                    , item: Just story
                    , storyId: Just storyId
                    }
                  pure unit
            else
              pure unit

  _ <- createEffect do
    maybeUserId <- get hnUserRequest
    case maybeUserId of
      Nothing -> pure unit
      Just userId -> do
        requestToken <- modify setHnUserToken (_ + 1)
        _ <- set setHnUserState
          { loading: true
          , error: Nothing
          , user: Nothing
          , userId: Just userId
          }
        launchAff_ do
          result <- HackerNews.fetchUser userId
          liftEffect do
            latestToken <- get hnUserToken
            if latestToken == requestToken then
              case result of
                Left message -> do
                  _ <- set setHnUserState
                    { loading: false
                    , error: Just message
                    , user: Nothing
                    , userId: Just userId
                    }
                  pure unit
                Right user -> do
                  _ <- set setHnUserState
                    { loading: false
                    , error: Nothing
                    , user: Just user
                    , userId: Just userId
                    }
                  pure unit
            else
              pure unit

  serverFunctionNode <- createMemo do
    result <- get serverFunctionResult
    pure (serverFunctionContent setCurrentRoute setServerFunctionResult result)

  routeNode <- createMemo do
    route <- get resolvedRoute
    serverFnRouteNode <- get serverFunctionNode
    storiesState <- get hnStoriesState
    storyState <- get hnStoryState
    userState <- get hnUserState
    pure (routeContent setCurrentRoute setHnPage serverFnRouteNode storiesState storyState userState route)

  _ <- createEffect do
    if Web.isServer then
      pure unit
    else do
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
            , HTML.a
                { className: hackerNewsLinkClass
                , href: routeHref "/hn"
                , onClick: Events.handler \event -> do
                    _ <- set setHnPage 1
                    navigateToRoute "/hn" setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
                }
                [ DOM.text "HackerNews" ]
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
  mountResult <- Web.requireBody
  case mountResult of
    Left webError ->
      log ("Mount error: " <> show webError)

    Right mountNode -> do
      renderResult <- Web.render (pure (Component.element app {})) mountNode
      case renderResult of
        Left webError ->
          log ("Render error: " <> show webError)
        Right _dispose ->
          pure unit
