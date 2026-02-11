module Solid.Start.Session
  ( Session
  , SessionStore
  , emptySession
  , withValue
  , lookupValue
  , createInMemoryStore
  ) where

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Ref as Ref
import Prelude

import Solid.Start.Error (StartError)

newtype Session = Session (Array (String /\ String))

derive instance eqSession :: Eq Session

instance showSession :: Show Session where
  show (Session values) = "Session " <> show values

type SessionStore =
  { read :: String -> Effect (Either StartError (Maybe Session))
  , write :: String -> Session -> Effect (Either StartError Unit)
  , delete :: String -> Effect (Either StartError Unit)
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

lookupSession :: String -> Array (String /\ Session) -> Maybe Session
lookupSession sessionId sessions =
  case Array.find (\(storedId /\ _) -> storedId == sessionId) sessions of
    Nothing -> Nothing
    Just (_ /\ session) -> Just session

upsertSession :: String -> Session -> Array (String /\ Session) -> Array (String /\ Session)
upsertSession sessionId session sessions =
  Array.filter (\(storedId /\ _) -> storedId /= sessionId) sessions <> [ sessionId /\ session ]
