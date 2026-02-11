module Solid.Start.Routing
  ( RouteDef
  , RouteMatch
  , MatchError(..)
  , matchPathIn
  ) where

import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Data.String.Pattern (Pattern(..))
import Data.Tuple.Nested ((/\), type (/\))
import Prelude

import Solid.Start.Route.Params (RouteParams(..))
import Solid.Start.Route.Pattern (RoutePattern(..), Segment(..))

type RouteDef =
  { id :: String
  , pattern :: RoutePattern
  , moduleName :: String
  , sourcePath :: String
  }

type RouteMatch =
  { route :: RouteDef
  , params :: RouteParams
  }

data MatchError
  = NoMatch String

derive instance eqMatchError :: Eq MatchError

instance showMatchError :: Show MatchError where
  show = case _ of
    NoMatch requestedPath -> "NoMatch " <> show requestedPath

matchPathIn :: Array RouteDef -> String -> Either MatchError RouteMatch
matchPathIn routes requestedPath =
  case bestCandidate of
    Nothing -> Left (NoMatch requestedPath)
    Just scoredMatch -> Right scoredMatch.routeMatch
  where
  requestedSegments = pathToSegments requestedPath

  bestCandidate :: Maybe ScoredMatch
  bestCandidate =
    foldl selectBetter Nothing (mapMaybeCandidate routes)

  mapMaybeCandidate :: Array RouteDef -> Array (Maybe ScoredMatch)
  mapMaybeCandidate = map toCandidate

  toCandidate :: RouteDef -> Maybe ScoredMatch
  toCandidate route =
    case route.pattern of
      RoutePattern patternSegments ->
        case matchSegments patternSegments requestedSegments emptyTrace of
          Nothing -> Nothing
          Just trace ->
            Just
              { routeMatch:
                  { route
                  , params: RouteParams trace.params
                  }
              , score: scoreMatch trace
              }

  selectBetter :: Maybe ScoredMatch -> Maybe ScoredMatch -> Maybe ScoredMatch
  selectBetter current incoming =
    case incoming of
      Nothing -> current
      Just incomingScored ->
        case current of
          Nothing -> Just incomingScored
          Just currentScored ->
            if incomingScored.score > currentScored.score then
              Just incomingScored
            else if incomingScored.score < currentScored.score then
              Just currentScored
            else if incomingScored.routeMatch.route.id < currentScored.routeMatch.route.id then
              Just incomingScored
            else
              Just currentScored

type MatchTrace =
  { params :: Array (String /\ String)
  , staticCount :: Int
  , paramCount :: Int
  , optionalConsumedCount :: Int
  , optionalSkippedCount :: Int
  , catchAllCount :: Int
  }

type ScoredMatch =
  { routeMatch :: RouteMatch
  , score :: Int
  }

emptyTrace :: MatchTrace
emptyTrace =
  { params: []
  , staticCount: 0
  , paramCount: 0
  , optionalConsumedCount: 0
  , optionalSkippedCount: 0
  , catchAllCount: 0
  }

scoreMatch :: MatchTrace -> Int
scoreMatch trace =
  (trace.staticCount * 1000)
    + (trace.paramCount * 100)
    + (trace.optionalConsumedCount * 25)
    - (trace.optionalSkippedCount * 5)
    - (trace.catchAllCount * 200)

appendParam :: String -> String -> MatchTrace -> MatchTrace
appendParam key value trace =
  trace { params = trace.params <> [ key /\ value ] }

pathToSegments :: String -> Array String
pathToSegments requestedPath =
  Array.filter (_ /= "") (String.split (Pattern "/") (stripQueryAndFragment requestedPath))

stripQueryAndFragment :: String -> String
stripQueryAndFragment value =
  takeBefore (Pattern "?") (takeBefore (Pattern "#") value)

takeBefore :: Pattern -> String -> String
takeBefore delimiter value =
  case Array.uncons (String.split delimiter value) of
    Nothing -> value
    Just { head: first } -> first

matchSegments :: Array Segment -> Array String -> MatchTrace -> Maybe MatchTrace
matchSegments patternSegments pathSegments trace =
  case Array.uncons patternSegments of
    Nothing ->
      if Array.null pathSegments then
        Just trace
      else
        Nothing
    Just { head: segment, tail: remainingPattern } ->
      case segment of
        Static expected ->
          case Array.uncons pathSegments of
            Just { head: actual, tail: rest }
              | actual == expected ->
                  matchSegments
                    remainingPattern
                    rest
                    (trace { staticCount = trace.staticCount + 1 })
            _ -> Nothing

        Param key ->
          case Array.uncons pathSegments of
            Just { head: actual, tail: rest } ->
              matchSegments
                remainingPattern
                rest
                (appendParam key actual (trace { paramCount = trace.paramCount + 1 }))
            _ -> Nothing

        CatchAll key ->
          if Array.null remainingPattern then
            let
              joined = String.joinWith "/" pathSegments
              traced = trace { catchAllCount = trace.catchAllCount + 1 }
            in
              if Array.null pathSegments then
                Just traced
              else
                Just (appendParam key joined traced)
          else
            Nothing

        Optional key ->
          chooseFirst
            [ consumeOptional key remainingPattern pathSegments trace
            , skipOptional remainingPattern pathSegments trace
            ]

consumeOptional
  :: String
  -> Array Segment
  -> Array String
  -> MatchTrace
  -> Maybe MatchTrace
consumeOptional key remainingPattern remainingPath trace =
  case Array.uncons remainingPath of
    Just { head: actual, tail: rest } ->
      matchSegments
        remainingPattern
        rest
        ( appendParam key actual
            (trace { optionalConsumedCount = trace.optionalConsumedCount + 1 })
        )
    _ -> Nothing

skipOptional :: Array Segment -> Array String -> MatchTrace -> Maybe MatchTrace
skipOptional remainingPattern remainingPath trace =
  matchSegments
    remainingPattern
    remainingPath
    (trace { optionalSkippedCount = trace.optionalSkippedCount + 1 })

chooseFirst :: forall a. Array (Maybe a) -> Maybe a
chooseFirst choices =
  case Array.uncons choices of
    Nothing -> Nothing
    Just { head: choice, tail: rest } ->
      case choice of
        Just value -> Just value
        Nothing -> chooseFirst rest
