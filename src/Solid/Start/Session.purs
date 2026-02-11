module Solid.Start.Session
  ( Session
  , SessionStore
  , CookieSessionConfig
  , CookieSessionAdapter
  , emptySession
  , withValue
  , lookupValue
  , createInMemoryStore
  , defaultCookieSessionConfig
  , createCookieSessionAdapter
  , encodeSessionToken
  , decodeSessionToken
  ) where

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.Pattern (Pattern(..))
import Data.Traversable (traverse)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Ref as Ref
import Prelude

import Solid.Start.Error (StartError(..))
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response

newtype Session = Session (Array (String /\ String))

derive instance eqSession :: Eq Session

instance showSession :: Show Session where
  show (Session values) = "Session " <> show values

type SessionStore =
  { read :: String -> Effect (Either StartError (Maybe Session))
  , write :: String -> Session -> Effect (Either StartError Unit)
  , delete :: String -> Effect (Either StartError Unit)
  }

type CookieSessionConfig =
  { cookieName :: String
  , path :: String
  , httpOnly :: Boolean
  , secure :: Boolean
  , sameSite :: String
  }

type CookieSessionAdapter =
  { readFromRequest :: Request.Request -> Effect (Either StartError Session)
  , writeToResponse :: Session -> Response.Response -> Effect (Either StartError Response.Response)
  , clearInResponse :: Response.Response -> Effect (Either StartError Response.Response)
  }

emptySession :: Session
emptySession = Session []

withValue :: String -> String -> Session -> Session
withValue key value (Session values) =
  Session
    (Array.filter (\(existingKey /\ _) -> existingKey /= key) values <> [ key /\ value ])

lookupValue :: String -> Session -> Maybe String
lookupValue key (Session values) =
  case Array.find (\(existingKey /\ _) -> existingKey == key) values of
    Nothing -> Nothing
    Just (_ /\ value) -> Just value

createInMemoryStore :: Effect SessionStore
createInMemoryStore = do
  ref <- Ref.new ([] :: Array (String /\ Session))

  let
    readSession sessionId = do
      sessions <- Ref.read ref
      pure (Right (lookupSession sessionId sessions))

    writeSession sessionId session = do
      Ref.modify_ (upsertSession sessionId session) ref
      pure (Right unit)

    deleteSession sessionId = do
      Ref.modify_ (Array.filter (\(storedId /\ _) -> storedId /= sessionId)) ref
      pure (Right unit)

  pure
    { read: readSession
    , write: writeSession
    , delete: deleteSession
    }

defaultCookieSessionConfig :: CookieSessionConfig
defaultCookieSessionConfig =
  { cookieName: "sid"
  , path: "/"
  , httpOnly: true
  , secure: false
  , sameSite: "Lax"
  }

createCookieSessionAdapter :: CookieSessionConfig -> CookieSessionAdapter
createCookieSessionAdapter config =
  { readFromRequest: \request ->
      case Request.lookupCookie config.cookieName request of
        Nothing -> pure (Right emptySession)
        Just encoded -> pure (decodeSessionToken encoded)
  , writeToResponse: \session response ->
      pure
        ( Right
            ( Response.withHeader
                "set-cookie"
                (buildSetCookieHeader config (encodeSessionToken session) false)
                response
            )
        )
  , clearInResponse: \response ->
      pure
        ( Right
            ( Response.withHeader
                "set-cookie"
                (buildSetCookieHeader config "" true)
                response
            )
        )
  }

lookupSession :: String -> Array (String /\ Session) -> Maybe Session
lookupSession sessionId sessions =
  case Array.find (\(storedId /\ _) -> storedId == sessionId) sessions of
    Nothing -> Nothing
    Just (_ /\ session) -> Just session

upsertSession :: String -> Session -> Array (String /\ Session) -> Array (String /\ Session)
upsertSession sessionId session sessions =
  Array.filter (\(storedId /\ _) -> storedId /= sessionId) sessions <> [ sessionId /\ session ]

encodeSessionToken :: Session -> String
encodeSessionToken (Session values) =
  String.joinWith "&" (map encodePair values)
  where
  encodePair (key /\ value) = key <> "=" <> value

decodeSessionToken :: String -> Either StartError Session
decodeSessionToken rawToken =
  Session <$> traverse decodePair tokenPairs
  where
  tokenPairs =
    if rawToken == "" then
      []
    else
      String.split (Pattern "&") rawToken

  decodePair rawPair =
    case Array.uncons parts of
      Nothing -> Left (SessionError "Invalid session cookie payload")
      Just { head: key, tail: rest } ->
        if key == "" then
          Left (SessionError "Session cookie key cannot be empty")
        else
          Right (key /\ String.joinWith "=" rest)
    where
    parts = String.split (Pattern "=") rawPair

buildSetCookieHeader :: CookieSessionConfig -> String -> Boolean -> String
buildSetCookieHeader config value clearing =
  String.joinWith "; " attributes
  where
  base =
    [ config.cookieName <> "=" <> value
    , "Path=" <> config.path
    , "SameSite=" <> config.sameSite
    ]

  withHttpOnly =
    if config.httpOnly then
      base <> [ "HttpOnly" ]
    else
      base

  withSecure =
    if config.secure then
      withHttpOnly <> [ "Secure" ]
    else
      withHttpOnly

  attributes =
    if clearing then
      withSecure <> [ "Max-Age=0" ]
    else
      withSecure
