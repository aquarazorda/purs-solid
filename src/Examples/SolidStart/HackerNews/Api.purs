module Examples.SolidStart.HackerNews.Api
  ( FeedType(..)
  , Story
  , StoryDetail
  , Comment(..)
  , User
  , feedLabel
  , feedRoutePath
  , fetchStories
  , fetchStory
  , fetchUser
  ) where

import Prelude

import Control.Promise as Promise
import Data.Either (Either)
import Data.Maybe (Maybe)
import Effect (Effect)
import Effect.Aff (Aff)

data FeedType
  = TopFeed
  | NewFeed
  | ShowFeed
  | AskFeed
  | JobFeed

derive instance eqFeedType :: Eq FeedType

instance showFeedType :: Show FeedType where
  show = case _ of
    TopFeed -> "TopFeed"
    NewFeed -> "NewFeed"
    ShowFeed -> "ShowFeed"
    AskFeed -> "AskFeed"
    JobFeed -> "JobFeed"

type Story =
  { id :: Int
  , title :: String
  , points :: Maybe Int
  , user :: Maybe String
  , timeAgo :: String
  , commentsCount :: Int
  , storyType :: String
  , url :: Maybe String
  , domain :: Maybe String
  }

newtype Comment = Comment
  { id :: Int
  , user :: Maybe String
  , timeAgo :: String
  , content :: String
  , comments :: Array Comment
  }

type StoryDetail =
  { id :: Int
  , title :: String
  , points :: Maybe Int
  , user :: Maybe String
  , timeAgo :: String
  , storyType :: String
  , url :: Maybe String
  , domain :: Maybe String
  , commentsCount :: Int
  , comments :: Array Comment
  }

type User =
  { id :: String
  , created :: Int
  , createdLabel :: String
  , karma :: Int
  , about :: Maybe String
  }

feedLabel :: FeedType -> String
feedLabel = case _ of
  TopFeed -> "Top"
  NewFeed -> "New"
  ShowFeed -> "Show"
  AskFeed -> "Ask"
  JobFeed -> "Jobs"

feedRoutePath :: FeedType -> String
feedRoutePath = case _ of
  TopFeed -> "/hn"
  NewFeed -> "/hn/new"
  ShowFeed -> "/hn/show"
  AskFeed -> "/hn/ask"
  JobFeed -> "/hn/job"

feedApiSegment :: FeedType -> String
feedApiSegment = case _ of
  TopFeed -> "news"
  NewFeed -> "newest"
  ShowFeed -> "show"
  AskFeed -> "ask"
  JobFeed -> "jobs"

fetchStories :: FeedType -> Int -> Aff (Either String (Array Story))
fetchStories feed page =
  Promise.toAffE (fetchStoriesImpl (feedApiSegment feed) page)

fetchStory :: String -> Aff (Either String StoryDetail)
fetchStory storyId =
  Promise.toAffE (fetchStoryImpl storyId)

fetchUser :: String -> Aff (Either String User)
fetchUser userId =
  Promise.toAffE (fetchUserImpl userId)

foreign import fetchStoriesImpl
  :: String
  -> Int
  -> Effect (Promise.Promise (Either String (Array Story)))

foreign import fetchStoryImpl
  :: String
  -> Effect (Promise.Promise (Either String StoryDetail))

foreign import fetchUserImpl
  :: String
  -> Effect (Promise.Promise (Either String User))
