module Solid.Start.Request.Event
  ( RequestContext
  , RequestEvent
  , emptyContext
  , mkRequestEvent
  , withContextValue
  , lookupContextValue
  , request
  ) where

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))
import Prelude

import Solid.Start.Server.Request as Request

newtype RequestContext = RequestContext (Array (String /\ String))

derive instance eqRequestContext :: Eq RequestContext

instance showRequestContext :: Show RequestContext where
  show (RequestContext values) = "RequestContext " <> show values

newtype RequestEvent = RequestEvent
  { request :: Request.Request
  , context :: RequestContext
  }

derive instance eqRequestEvent :: Eq RequestEvent

instance showRequestEvent :: Show RequestEvent where
  show (RequestEvent event) =
    "RequestEvent { request: " <> show event.request <> ", context: " <> show event.context <> " }"

emptyContext :: RequestContext
emptyContext = RequestContext []

mkRequestEvent :: Request.Request -> RequestEvent
mkRequestEvent req =
  RequestEvent
    { request: req
    , context: emptyContext
    }

withContextValue :: String -> String -> RequestEvent -> RequestEvent
withContextValue key value (RequestEvent event) =
  RequestEvent
    ( event
        { context = putValue key value event.context
        }
    )

lookupContextValue :: String -> RequestEvent -> Maybe String
lookupContextValue key (RequestEvent event) =
  lookupValue key event.context

request :: RequestEvent -> Request.Request
request (RequestEvent event) = event.request

putValue :: String -> String -> RequestContext -> RequestContext
putValue key value (RequestContext values) =
  RequestContext
    (Array.filter (\(existingKey /\ _) -> existingKey /= key) values <> [ key /\ value ])

lookupValue :: String -> RequestContext -> Maybe String
lookupValue key (RequestContext values) =
  case Array.find (\(existingKey /\ _) -> existingKey == key) values of
    Nothing -> Nothing
    Just (_ /\ value) -> Just value
