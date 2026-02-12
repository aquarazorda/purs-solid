module Examples.SolidStart.RouteView
  ( HnRoute(..)
  , RouteView(..)
  , resolveRouteView
  ) where

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))

import Examples.SolidStart.HackerNews.Api as HackerNews
import Solid.Start.Route.Params as RouteParams
import Solid.Start.Routing.Manifest as StartManifest

data HnRoute
  = HnFeedRoute HackerNews.FeedType
  | HnStoryRoute String
  | HnUserRoute String

data RouteView
  = HackerNewsView HnRoute
  | NotFoundView String

resolveRouteView :: String -> RouteView
resolveRouteView routePath =
  case StartManifest.matchPath routePath of
    Left _ -> NotFoundView routePath
    Right routeMatch ->
      case routeMatch.route.id of
        "/stories/:id" ->
          case RouteParams.lookupParam "id" routeMatch.params of
            Just storyId -> HackerNewsView (HnStoryRoute storyId)
            Nothing -> NotFoundView routePath
        "/users/:id" ->
          case RouteParams.lookupParam "id" routeMatch.params of
            Just userId -> HackerNewsView (HnUserRoute userId)
            Nothing -> NotFoundView routePath
        "/*stories" ->
          case decodeFeed (RouteParams.lookupParam "stories" routeMatch.params) of
            Just feed -> HackerNewsView (HnFeedRoute feed)
            Nothing -> NotFoundView routePath
        _ -> NotFoundView routePath

decodeFeed :: Maybe String -> Maybe HackerNews.FeedType
decodeFeed maybeSegment =
  case maybeSegment of
    Nothing -> Just HackerNews.TopFeed
    Just "" -> Just HackerNews.TopFeed
    Just "top" -> Just HackerNews.TopFeed
    Just "new" -> Just HackerNews.NewFeed
    Just "show" -> Just HackerNews.ShowFeed
    Just "ask" -> Just HackerNews.AskFeed
    Just "job" -> Just HackerNews.JobFeed
    _ -> Nothing
