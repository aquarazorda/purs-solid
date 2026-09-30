module Test.Solid
  ( solidIt
  , expectDiagnostic
  , jsxValue
  , module Exports
  ) where

import Prelude

import Control.Monad.Error.Class (throwError, try)
import Data.Array as Array
import Data.Either (either)
import Data.String (joinWith)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.JSX (JSX)
import Solid.Testing (collectDiagnostics, ignoreDiagnostic, settle)
import Solid.Testing (Mounted, click, html, inputText, mount, mountUsing, query, settle) as Exports
import Test.Spec (Spec, it)

-- | A spec that fails on any Solid diagnostic above `info`.
solidIt :: String -> Aff Unit -> Spec Unit
solidIt name body = it name do
  stop <- liftEffect collectDiagnostics
  outcome <- try (body *> settle)
  diagnostics <- liftEffect stop
  either throwError pure outcome
  let reported = Array.filter (\d -> d.severity /= "info") diagnostics
  unless (Array.null reported) do
    liftEffect $ throw $ "Solid reported diagnostics:\n" <> joinWith "\n" (reported <#> \d -> d.code <> ": " <> d.message)

expectDiagnostic :: String -> Aff Unit -> Aff Unit
expectDiagnostic code body = do
  stop <- liftEffect collectDiagnostics
  _ <- try (body *> settle)
  diagnostics <- liftEffect stop
  unless (Array.any (\d -> d.code == code) diagnostics) do
    liftEffect $ throw $ "Expected diagnostic " <> code <> ", got: " <> joinWith ", " (_.code <$> diagnostics)
  liftEffect (ignoreDiagnostic code)

foreign import jsxValue :: JSX -> Effect String
