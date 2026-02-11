module Solid.Start.Route.Params
  ( RouteParamError(..)
  , RouteParams(..)
  , empty
  , singleton
  , toArray
  , lookupParam
  , requireParam
  , decodeParamWith
  ) where

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))
import Prelude

data RouteParamError
  = MissingParam String
  | InvalidParam String String

derive instance eqRouteParamError :: Eq RouteParamError

instance showRouteParamError :: Show RouteParamError where
  show = case _ of
    MissingParam key -> "MissingParam " <> show key
    InvalidParam key message -> "InvalidParam " <> show key <> " " <> show message

newtype RouteParams = RouteParams (Array (String /\ String))

derive instance eqRouteParams :: Eq RouteParams

instance showRouteParams :: Show RouteParams where
  show (RouteParams params) = "RouteParams " <> show params

empty :: RouteParams
empty = RouteParams []

singleton :: String -> String -> RouteParams
singleton key value = RouteParams [ key /\ value ]

toArray :: RouteParams -> Array (String /\ String)
toArray (RouteParams params) = params

lookupParam :: String -> RouteParams -> Maybe String
lookupParam key (RouteParams params) =
  case Array.find (\(currentKey /\ _) -> currentKey == key) params of
    Nothing -> Nothing
    Just (_ /\ value) -> Just value

requireParam :: String -> RouteParams -> Either RouteParamError String
requireParam key params =
  case lookupParam key params of
    Nothing -> Left (MissingParam key)
    Just value -> Right value

decodeParamWith
  :: forall a
   . (String -> Either String a)
  -> String
  -> RouteParams
  -> Either RouteParamError a
decodeParamWith decode key params =
  case requireParam key params of
    Left errorValue -> Left errorValue
    Right rawValue ->
      case decode rawValue of
        Left message -> Left (InvalidParam key message)
        Right decoded -> Right decoded
