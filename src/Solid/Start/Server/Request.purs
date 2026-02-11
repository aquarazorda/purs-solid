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
  , withHeader
  , lookupHeader
  , lookupCookie
  , lookupQuery
  , parseMethod
  , methodToString
  ) where

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as StringCodeUnits
import Data.String.Pattern (Pattern(..))
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

withHeader :: String -> String -> Request -> Request
withHeader key value (Request request) =
  Request
    ( request
        { headers =
            Array.filter (\(currentKey /\ _) -> currentKey /= key) request.headers
              <> [ key /\ value ]
        }
    )

lookupHeader :: String -> Request -> Maybe String
lookupHeader key request =
  lookupPair key (headers request)

lookupCookie :: String -> Request -> Maybe String
lookupCookie key request =
  case lookupCookieHeader request of
    Nothing -> Nothing
    Just rawCookieHeader ->
      lookupCookiePair key (String.split (Pattern ";") rawCookieHeader)

lookupQuery :: String -> Request -> Maybe String
lookupQuery key request =
  lookupPair key (queryParams request)

lookupCookieHeader :: Request -> Maybe String
lookupCookieHeader (Request request) =
  case Array.find hasCookieKey request.headers of
    Nothing -> Nothing
    Just (_ /\ value) -> Just value
  where
  hasCookieKey (headerKey /\ _) =
    headerKey == "cookie" || headerKey == "Cookie"

lookupCookiePair :: String -> Array String -> Maybe String
lookupCookiePair key cookiePairs =
  case Array.uncons cookiePairs of
    Nothing -> Nothing
    Just { head: pair, tail: remaining } ->
      case parseCookiePair key pair of
        Nothing -> lookupCookiePair key remaining
        Just value -> Just value

parseCookiePair :: String -> String -> Maybe String
parseCookiePair key rawPair =
  case Array.uncons parts of
    Nothing -> Nothing
    Just { head: rawCookieKey, tail: rest } ->
      let
        normalizedKey = stripLeadingSpaces rawCookieKey
      in
        if normalizedKey == key then
          Just (String.joinWith "=" rest)
        else
          Nothing
  where
  parts = String.split (Pattern "=") rawPair

stripLeadingSpaces :: String -> String
stripLeadingSpaces value =
  if StringCodeUnits.take 1 value == " " then
    stripLeadingSpaces (StringCodeUnits.drop 1 value)
  else
    value

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
