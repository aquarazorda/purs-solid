module Test.Start.Manifest
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Effect.Exception (throw)
import Solid.Start.Routing (MatchError(..), RouteMatch)
import Solid.Start.Routing.Manifest (matchPath)
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  root <- expectMatch "manifest root route" "/"
  assertEqual "manifest root route id" "/" root.route.id

  counter <- expectMatch "manifest counter route" "/counter"
  assertEqual "manifest counter route id" "/counter" counter.route.id

  todomvc <- expectMatch "manifest todomvc route" "/todomvc"
  assertEqual "manifest todomvc route id" "/todomvc" todomvc.route.id

  assertEqual
    "manifest no match returns typed error"
    (Left (NoMatch "/missing"))
    (matchPath "/missing")

expectMatch
  :: String
  -> String
  -> Effect RouteMatch
expectMatch label path =
  case matchPath path of
    Left errorValue ->
      throw (label <> ": expected match, got " <> show errorValue)
    Right routeMatch ->
      pure routeMatch
