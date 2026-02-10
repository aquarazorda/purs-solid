module Test.Assert
  ( assertEqual
  , expectRight
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Effect.Exception (throw)

assertEqual :: forall a. Eq a => Show a => String -> a -> a -> Effect Unit
assertEqual label expected actual =
  if expected == actual then
    pure unit
  else
    throw (label <> ": expected " <> show expected <> ", got " <> show actual)

expectRight :: forall l r. Show l => String -> Either l r -> Effect r
expectRight label result =
  case result of
    Left leftValue ->
      throw (label <> ": unexpected Left " <> show leftValue)
    Right rightValue ->
      pure rightValue
