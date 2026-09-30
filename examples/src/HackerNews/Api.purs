module Examples.HackerNews.Api
  ( Feed(..)
  , parseFeed
  , feedPath
  , feedLabel
  , module Exports
  , stories
  , story
  , user
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable)
import Effect.Aff (Aff)
import Examples.HackerNews.Server (Story, StoryPage, User)
import Examples.HackerNews.Server (Comment, Story, StoryPage, User) as Exports
import Examples.HackerNews.Server as Server
import Solid.Router.Query (Query, queryServer, runQuery)

data Feed = Top | New | ShowHN | Ask | Jobs

derive instance Eq Feed

parseFeed :: String -> Maybe Feed
parseFeed = case _ of
  "new" -> Just New
  "show" -> Just ShowHN
  "ask" -> Just Ask
  "job" -> Just Jobs
  _ -> Nothing

feedPath :: Feed -> String
feedPath = case _ of
  Top -> "/"
  New -> "/new"
  ShowHN -> "/show"
  Ask -> "/ask"
  Jobs -> "/job"

feedLabel :: Feed -> String
feedLabel = case _ of
  Top -> "HN"
  New -> "New"
  ShowHN -> "Show"
  Ask -> "Ask"
  Jobs -> "Jobs"

apiFeed :: Feed -> String
apiFeed = case _ of
  Top -> "topstories"
  New -> "newstories"
  ShowHN -> "showstories"
  Ask -> "askstories"
  Jobs -> "jobstories"

storiesQuery :: Query { feed :: String, page :: Int } (Array Story)
storiesQuery = queryServer Server.stories

storyQuery :: Query Int (Nullable StoryPage)
storyQuery = queryServer Server.story

userQuery :: Query String (Nullable User)
userQuery = queryServer Server.user

stories :: Feed -> Int -> Aff (Array Story)
stories feed page = runQuery storiesQuery { feed: apiFeed feed, page }

story :: Int -> Aff (Nullable StoryPage)
story = runQuery storyQuery

user :: String -> Aff (Nullable User)
user = runQuery userQuery
