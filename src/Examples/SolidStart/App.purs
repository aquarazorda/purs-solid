module Examples.SolidStart.App
  ( app
  , appWithRoute
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)

import Examples.SolidStart.Config (basePath, linkClass, routeHref)
import Examples.SolidStart.HackerNews.Api as HackerNews
import Examples.SolidStart.Navigation (navigateToRoute)
import Examples.SolidStart.RouteView (HnRoute(..), RouteView(..), resolveRouteView)
import Examples.SolidStart.View.HackerNews (HnStoriesState, HnStoryState, HnUserState, hackerNewsContent, initialHnStoriesState, initialHnStoryState, initialHnUserState)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM as DOM
import Solid.DOM.Events as Events
import Solid.DOM.HTML as HTML
import Solid.JSX (JSX)
import Solid.Lifecycle (onCleanup, onMount)
import Solid.Reactivity (createEffect, createMemo)
import Solid.Router.Navigation as RouterNavigation
import Solid.Signal (Accessor, Setter, createSignal, get, modify, set)

notFoundContent :: Setter String -> String -> JSX
notFoundContent setCurrentRoute routePath =
  HTML.section { className: "item-view" }
    [ HTML.div { className: "item-view-header" }
        [ HTML.h1_ [ DOM.text "Route not found" ]
        , HTML.p { className: "meta" }
            [ DOM.text "No route matched: "
            , DOM.text routePath
            ]
        , HTML.p { className: "meta" }
            [ HTML.a
                { href: routeHref "/"
                , onClick: Events.handler_ (navigateToRoute "/" setCurrentRoute)
                }
                [ DOM.text "Back to feed" ]
            ]
        ]
    ]

routeContent
  :: Setter String
  -> Setter Int
  -> HnStoriesState
  -> HnStoryState
  -> HnUserState
  -> RouteView
  -> JSX
routeContent setCurrentRoute setHnPage storiesState storyState userState route =
  case route of
    HackerNewsView hnRoute ->
      hackerNewsContent setCurrentRoute setHnPage storiesState storyState userState hnRoute
    NotFoundView routePath ->
      notFoundContent setCurrentRoute routePath

navLink
  :: Setter String
  -> Setter Int
  -> Accessor String
  -> String
  -> String
  -> JSX
navLink setCurrentRoute setHnPage activeClass routeId label =
  HTML.a
    { className: activeClass
    , href: routeHref routeId
    , onClick: Events.handler_ do
        _ <- set setHnPage 1
        navigateToRoute routeId setCurrentRoute
    }
    [ HTML.strong_ [ DOM.text label ] ]

mkApp :: Effect String -> Component.Component {}
mkApp resolveInitialRoute = Component.component \_ -> do
  initialRoute <- resolveInitialRoute
  currentRoute /\ setCurrentRoute <- createSignal initialRoute
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

  topLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/")

  newLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/new")

  showLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/show")

  askLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/ask")

  jobLinkClass <- createMemo do
    route <- get currentRoute
    pure (linkClass route "/job")

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

  routeNode <- createMemo do
    route <- get resolvedRoute
    storiesState <- get hnStoriesState
    storyState <- get hnStoryState
    userState <- get hnUserState
    pure (routeContent setCurrentRoute setHnPage storiesState storyState userState route)

  _ <- onMount do
    unsubscribe <- RouterNavigation.subscribeRouteChanges basePath \nextRoute -> do
      _ <- set setCurrentRoute nextRoute
      pure unit
    _ <- onCleanup unsubscribe
    pure unit

  pure $ HTML.div_
    [ HTML.header { className: "header" }
        [ HTML.nav { className: "inner" }
            [ navLink setCurrentRoute setHnPage topLinkClass "/" "HN"
            , navLink setCurrentRoute setHnPage newLinkClass "/new" "New"
            , navLink setCurrentRoute setHnPage showLinkClass "/show" "Show"
            , navLink setCurrentRoute setHnPage askLinkClass "/ask" "Ask"
            , navLink setCurrentRoute setHnPage jobLinkClass "/job" "Jobs"
            , HTML.a
                { className: "github"
                , href: "http://github.com/solidjs/solid"
                , target: "_blank"
                , rel: "noreferrer"
                }
                [ DOM.text "Built with Solid" ]
            ]
        ]
    , HTML.div { className: "view" }
        [ Control.dynamicTag "div" { children: routeNode } ]
    ]

app :: Component.Component {}
app = mkApp (RouterNavigation.startRoutePath basePath)

appWithRoute :: String -> Component.Component {}
appWithRoute routePath = mkApp (pure routePath)
