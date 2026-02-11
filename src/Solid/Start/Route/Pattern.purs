module Solid.Start.Route.Pattern
  ( Segment(..)
  , RoutePattern(..)
  ) where

import Prelude

data Segment
  = Static String
  | Param String
  | CatchAll String
  | Optional String

derive instance eqSegment :: Eq Segment

instance showSegment :: Show Segment where
  show = case _ of
    Static value -> "Static " <> show value
    Param value -> "Param " <> show value
    CatchAll value -> "CatchAll " <> show value
    Optional value -> "Optional " <> show value

newtype RoutePattern = RoutePattern (Array Segment)

derive instance eqRoutePattern :: Eq RoutePattern

instance showRoutePattern :: Show RoutePattern where
  show (RoutePattern segments) = "RoutePattern " <> show segments
