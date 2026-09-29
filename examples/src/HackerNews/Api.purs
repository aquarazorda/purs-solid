module Examples.HackerNews.Api
  ( Feed(..)
  , parseFeed
  , feedPath
  , feedLabel
  , Story
  , Comment
  , StoryPage
  , User
  , stories
  , story
  , user
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable)
import Effect.Aff (Aff)
import Solid.Router.Query (Query, queryServer, runQuery)
import Solid.Start.ServerFunction (ServerFunction)

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

type Story =
  { id :: Int
  , title :: String
  , url :: Nullable String
  , points :: Int
  , by :: Nullable String
  , time :: Int
  , comments :: Int
  }

type Comment =
  { id :: Int
  , parent :: Int
  , by :: Nullable String
  , html :: String
  , time :: Int
  }

type StoryPage = { story :: Story, comments :: Array Comment }

type User = { id :: String, created :: Int, karma :: Int, about :: Nullable String }

foreign import storiesOnServer :: ServerFunction { feed :: String, page :: Int } (Array Story)
foreign import storyOnServer :: ServerFunction Int (Nullable StoryPage)
foreign import userOnServer :: ServerFunction String (Nullable User)

storiesQuery :: Query { feed :: String, page :: Int } (Array Story)
storiesQuery = queryServer "hn.stories" storiesOnServer

storyQuery :: Query Int (Nullable StoryPage)
storyQuery = queryServer "hn.story" storyOnServer

userQuery :: Query String (Nullable User)
userQuery = queryServer "hn.user" userOnServer

stories :: Feed -> Int -> Aff (Array Story)
stories feed page = runQuery storiesQuery { feed: apiFeed feed, page }

story :: Int -> Aff (Nullable StoryPage)
story = runQuery storyQuery

user :: String -> Aff (Nullable User)
user = runQuery userQuery
