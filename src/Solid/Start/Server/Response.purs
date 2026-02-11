module Solid.Start.Server.Response
  ( ResponseBody(..)
  , Response
  , mkResponse
  , text
  , json
  , html
  , redirect
  , methodNotAllowed
  , withHeader
  , status
  , headers
  , body
  ) where

import Data.Tuple.Nested ((/\), type (/\))
import Prelude

import Solid.Start.Server.Request (Method, methodToString)

data ResponseBody
  = EmptyBody
  | TextBody String
  | JsonBody String
  | HtmlBody String

derive instance eqResponseBody :: Eq ResponseBody

instance showResponseBody :: Show ResponseBody where
  show = case _ of
    EmptyBody -> "EmptyBody"
    TextBody value -> "TextBody " <> show value
    JsonBody value -> "JsonBody " <> show value
    HtmlBody value -> "HtmlBody " <> show value

newtype Response = Response
  { status :: Int
  , headers :: Array (String /\ String)
  , body :: ResponseBody
  }

derive instance eqResponse :: Eq Response

instance showResponse :: Show Response where
  show (Response response) =
    "Response { status: " <> show response.status
      <> ", headers: "
      <> show response.headers
      <> ", body: "
      <> show response.body
      <> " }"

mkResponse :: Int -> Array (String /\ String) -> ResponseBody -> Response
mkResponse code responseHeaders responseBody =
  Response
    { status: code
    , headers: responseHeaders
    , body: responseBody
    }

text :: Int -> String -> Response
text code content =
  mkResponse
    code
    [ "content-type" /\ "text/plain; charset=utf-8" ]
    (TextBody content)

json :: Int -> String -> Response
json code content =
  mkResponse
    code
    [ "content-type" /\ "application/json; charset=utf-8" ]
    (JsonBody content)

html :: Int -> String -> Response
html code content =
  mkResponse
    code
    [ "content-type" /\ "text/html; charset=utf-8" ]
    (HtmlBody content)

redirect :: Int -> String -> Response
redirect code location =
  mkResponse
    code
    [ "location" /\ location ]
    EmptyBody

methodNotAllowed :: Method -> Response
methodNotAllowed allowedMethod =
  mkResponse
    405
    [ "allow" /\ methodToString allowedMethod
    , "content-type" /\ "text/plain; charset=utf-8"
    ]
    (TextBody "Method Not Allowed")

withHeader :: String -> String -> Response -> Response
withHeader key value (Response response) =
  Response (response { headers = response.headers <> [ key /\ value ] })

status :: Response -> Int
status (Response response) = response.status

headers :: Response -> Array (String /\ String)
headers (Response response) = response.headers

body :: Response -> ResponseBody
body (Response response) = response.body
