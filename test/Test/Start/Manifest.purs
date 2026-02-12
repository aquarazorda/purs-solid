module Test.Start.Manifest
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Exception (throw)
import Solid.Router.Route.Params as RouteParams
import Solid.Router.Routing (RouteMatch)
import Solid.Router.Routing.Manifest (matchPath)
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  root <- expectMatch "manifest root route" "/"
  assertEqual "manifest root route id" "/*stories" root.route.id

  newFeed <- expectMatch "manifest new feed route" "/new"
  assertEqual "manifest new feed route id" "/*stories" newFeed.route.id

  story <- expectMatch "manifest story route" "/stories/100"
  assertEqual "manifest story route id" "/stories/:id" story.route.id
  assertEqual "manifest story id param" (Just "100") (RouteParams.lookupParam "id" story.params)

  user <- expectMatch "manifest user route" "/users/alice"
  assertEqual "manifest user route id" "/users/:id" user.route.id
  assertEqual "manifest user id param" (Just "alice") (RouteParams.lookupParam "id" user.params)

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
