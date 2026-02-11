module Solid.Start.Server.Request
  ( Method(..)
  , Header
  , QueryParam
  , Request
  , mkRequest
  , method
  , path
  , headers
  , queryParams
  , body
  , lookupHeader
  , lookupQuery
  , parseMethod
  , methodToString
  ) where

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))
import Prelude

data Method
  = GET
  | POST
  | PUT
  | PATCH
  | DELETE
  | OPTIONS
  | HEAD

derive instance eqMethod :: Eq Method

instance showMethod :: Show Method where
  show = methodToString

type Header = String /\ String

type QueryParam = String /\ String

newtype Request = Request
  { method :: Method
  , path :: String
  , headers :: Array Header
  , query :: Array QueryParam
  , body :: Maybe String
  }

derive instance eqRequest :: Eq Request

instance showRequest :: Show Request where
  show (Request request) =
    "Request { method: " <> show request.method
      <> ", path: "
      <> show request.path
      <> ", headers: "
      <> show request.headers
      <> ", query: "
      <> show request.query
      <> ", body: "
      <> show request.body
      <> " }"

mkRequest :: Method -> String -> Array Header -> Array QueryParam -> Maybe String -> Request
mkRequest requestMethod requestPath requestHeaders requestQuery requestBody =
  Request
    { method: requestMethod
    , path: requestPath
    , headers: requestHeaders
    , query: requestQuery
    , body: requestBody
    }

method :: Request -> Method
method (Request request) = request.method

path :: Request -> String
path (Request request) = request.path

headers :: Request -> Array Header
headers (Request request) = request.headers

queryParams :: Request -> Array QueryParam
queryParams (Request request) = request.query

body :: Request -> Maybe String
body (Request request) = request.body

lookupHeader :: String -> Request -> Maybe String
lookupHeader key request =
  lookupPair key (headers request)

lookupQuery :: String -> Request -> Maybe String
lookupQuery key request =
  lookupPair key (queryParams request)

lookupPair :: String -> Array (String /\ String) -> Maybe String
lookupPair key pairs =
  case Array.find (\(currentKey /\ _) -> currentKey == key) pairs of
    Nothing -> Nothing
    Just (_ /\ value) -> Just value

methodToString :: Method -> String
methodToString = case _ of
  GET -> "GET"
  POST -> "POST"
  PUT -> "PUT"
  PATCH -> "PATCH"
  DELETE -> "DELETE"
  OPTIONS -> "OPTIONS"
  HEAD -> "HEAD"

parseMethod :: String -> Maybe Method
parseMethod value =
  case value of
    "GET" -> Just GET
    "POST" -> Just POST
    "PUT" -> Just PUT
    "PATCH" -> Just PATCH
    "DELETE" -> Just DELETE
    "OPTIONS" -> Just OPTIONS
    "HEAD" -> Just HEAD
    _ -> Nothing
