module Examples.HackerNews.Server
  ( module Solid.Start.UseServer
  , Story
  , Comment
  , StoryPage
  , User
  , stories
  , story
  , user
  ) where

import Prelude

import Control.Monad.Error.Class (throwError)
import Control.Parallel (parTraverse)
import Data.Argonaut.Decode (class DecodeJson, decodeJson, parseJson, printJsonDecodeError)
import Data.Array as Array
import Data.Either (either)
import Data.Maybe (Maybe, fromMaybe)
import Data.Nullable (Nullable, toNullable)
import Data.Traversable (traverse)
import Effect.Aff (Aff)
import Effect.Exception (error)
import Fetch (fetch)
import JSURI (encodeURIComponent)
import Solid.Start.ServerFunction (ServerFunction, serverFunction)
import Solid.Start.UseServer (useServer)

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

type Item =
  { id :: Int
  , title :: Maybe String
  , url :: Maybe String
  , score :: Maybe Int
  , by :: Maybe String
  , time :: Maybe Int
  , descendants :: Maybe Int
  , kids :: Maybe (Array Int)
  , deleted :: Maybe Boolean
  , dead :: Maybe Boolean
  , text :: Maybe String
  }

pageSize :: Int
pageSize = 30

maxComments :: Int
maxComments = 200

getJson :: forall a. DecodeJson a => String -> Aff a
getJson path = do
  response <- fetch ("https://hacker-news.firebaseio.com/v0/" <> path <> ".json") {}
  unless response.ok $ throwError (error ("Hacker News API: " <> show response.status))
  body <- response.text
  either (throwError <<< error <<< printJsonDecodeError) pure (parseJson body >>= decodeJson)

item :: Int -> Aff (Maybe Item)
item id = getJson ("item/" <> show id)

live :: Item -> Boolean
live found = not (fromMaybe false found.deleted || fromMaybe false found.dead)

toStory :: Item -> Story
toStory found =
  { id: found.id
  , title: fromMaybe "" found.title
  , url: toNullable found.url
  , points: fromMaybe 0 found.score
  , by: toNullable found.by
  , time: fromMaybe 0 found.time
  , comments: fromMaybe 0 found.descendants
  }

replies :: Item -> Array { kid :: Int, parent :: Int }
replies found = { kid: _, parent: found.id } <$> fromMaybe [] found.kids

stories :: ServerFunction { feed :: String, page :: Int } (Array Story)
stories = serverFunction \{ feed, page } -> do
  ids <- getJson feed
  items <- parTraverse item (Array.slice ((page - 1) * pageSize) (page * pageSize) ids)
  pure (toStory <$> Array.filter (not <<< fromMaybe false <<< _.deleted) (Array.catMaybes items))

story :: ServerFunction Int (Nullable StoryPage)
story = serverFunction \id -> item id >>= map toNullable <<< traverse \found -> do
  comments <- loadComments (replies found) []
  pure { story: toStory found, comments }
  where
  loadComments frontier loaded
    | Array.null frontier || Array.length loaded >= maxComments = pure loaded
    | otherwise = do
        let batch = Array.take (maxComments - Array.length loaded) frontier
        items <- parTraverse (item <<< _.kid) batch
        let kept = Array.filter (live <<< _.found) (Array.catMaybes (Array.zipWith (\{ parent } -> map { parent, found: _ }) batch items))
        loadComments (kept >>= replies <<< _.found) $ loaded <> map toComment kept
  toComment { parent, found } = { id: found.id, parent, by: toNullable found.by, html: fromMaybe "" found.text, time: fromMaybe 0 found.time }

user :: ServerFunction String (Nullable User)
user = serverFunction \id -> do
  found :: Maybe { id :: String, created :: Maybe Int, karma :: Maybe Int, about :: Maybe String } <-
    getJson ("user/" <> fromMaybe id (encodeURIComponent id))
  pure $ toNullable $ found <#> \u ->
    { id: u.id, created: fromMaybe 0 u.created, karma: fromMaybe 0 u.karma, about: toNullable u.about }
