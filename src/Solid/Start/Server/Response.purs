module Solid.Start.Server.Response
  ( ResponseBody(..)
  , Response
  , mkResponse
  , text
  , json
  , html
  , streamText
  , redirect
  , okText
  , okJson
  , okHtml
  , okStreamText
  , createdJson
  , acceptedText
  , noContent
  , badRequestText
  , unauthorizedText
  , forbiddenText
  , notFoundText
  , conflictText
  , unprocessableEntityText
  , internalServerErrorText
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
  | StreamBody (Array String)

derive instance eqResponseBody :: Eq ResponseBody

instance showResponseBody :: Show ResponseBody where
  show = case _ of
    EmptyBody -> "EmptyBody"
    TextBody value -> "TextBody " <> show value
    JsonBody value -> "JsonBody " <> show value
    HtmlBody value -> "HtmlBody " <> show value
    StreamBody chunks -> "StreamBody " <> show chunks

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

streamText :: Int -> Array String -> Response
streamText code chunks =
  mkResponse
    code
    [ "content-type" /\ "text/plain; charset=utf-8" ]
    (StreamBody chunks)

redirect :: Int -> String -> Response
redirect code location =
  mkResponse
    code
    [ "location" /\ location ]
    EmptyBody

okText :: String -> Response
okText = text 200

okJson :: String -> Response
okJson = json 200

okHtml :: String -> Response
okHtml = html 200

okStreamText :: Array String -> Response
okStreamText = streamText 200

createdJson :: String -> Response
createdJson = json 201

acceptedText :: String -> Response
acceptedText = text 202

noContent :: Response
noContent = mkResponse 204 [] EmptyBody

badRequestText :: String -> Response
badRequestText = text 400

unauthorizedText :: String -> Response
unauthorizedText = text 401

forbiddenText :: String -> Response
forbiddenText = text 403

notFoundText :: String -> Response
notFoundText = text 404

conflictText :: String -> Response
conflictText = text 409

unprocessableEntityText :: String -> Response
unprocessableEntityText = text 422

internalServerErrorText :: String -> Response
internalServerErrorText = text 500

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
