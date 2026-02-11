module Test.Start.Core
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Solid.Start.App as App
import Solid.Start.Error (StartError(..), fromRouteMiss)
import Solid.Start.Route.Params as RouteParams
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  assertEqual "defaultStartConfig basePath" "/" App.defaultStartConfig.basePath
  assertEqual "defaultStartConfig assetPrefix" "/" App.defaultStartConfig.assetPrefix
  assertEqual "defaultStartConfig isDev" true App.defaultStartConfig.isDev

  assertEqual
    "fromRouteMiss maps path to RouteNotFound"
    (RouteNotFound "No route matched path: /missing")
    (fromRouteMiss "/missing")

  let params = RouteParams.singleton "slug" "solid-start"
  assertEqual
    "lookupParam returns value when key exists"
    (Just "solid-start")
    (RouteParams.lookupParam "slug" params)
  assertEqual
    "requireParam returns MissingParam for absent key"
    (Left (RouteParams.MissingParam "id"))
    (RouteParams.requireParam "id" params)

  assertEqual
    "decodeParamWith maps decoder success"
    (Right 42)
    ( RouteParams.decodeParamWith decodeIntLike "n"
        (RouteParams.singleton "n" "42")
    )
  assertEqual
    "decodeParamWith maps decoder failures to InvalidParam"
    (Left (RouteParams.InvalidParam "n" "expected 42"))
    ( RouteParams.decodeParamWith decodeIntLike "n"
        (RouteParams.singleton "n" "abc")
    )

decodeIntLike :: String -> Either String Int
decodeIntLike value =
  if value == "42" then
    Right 42
  else
    Left "expected 42"
