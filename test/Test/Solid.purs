-- | Test helpers for Solid 2 semantics.
module Test.Solid
  ( solidIt
  , settle
  , expectDiagnostic
  , jsxValue
  ) where

import Prelude

import Data.Array as Array
import Data.String (joinWith)
import Effect (Effect)
import Control.Monad.Error.Class (throwError, try)
import Data.Either (either)
import Effect.Aff (Aff, Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.Reactivity (flush)
import Test.Spec (Spec, it)

type Diagnostic = { code :: String, severity :: String, message :: String }

-- | Starts collecting Solid dev diagnostics; the returned effect stops and
-- | returns what was collected. Fails loudly if the dev build isn't loaded.
foreign import collectDiagnostics :: Effect (Effect (Array Diagnostic))

-- | `it`, failing the test if Solid reports any warning or error diagnostic
-- | (e.g. `REACTIVE_WRITE_IN_OWNED_SCOPE`, `STRICT_READ_UNTRACKED`).
solidIt :: String -> Aff Unit -> Spec Unit
solidIt name body = it name do
  stop <- liftEffect collectDiagnostics
  outcome <- try (body *> settle)
  diagnostics <- liftEffect stop
  either throwError pure outcome
  let reported = Array.filter (\d -> d.severity /= "info") diagnostics
  unless (Array.null reported) do
    liftEffect $ throw $ "Solid reported diagnostics:\n" <> joinWith "\n" (reported <#> \d -> d.code <> ": " <> d.message)

-- | Runs `body` (which may throw) and requires Solid to report the diagnostic
-- | `code`: for tests documenting what the runtime still guards behind the
-- | `unsafe` escape hatches.
expectDiagnostic :: String -> Aff Unit -> Aff Unit
expectDiagnostic code body = do
  stop <- liftEffect collectDiagnostics
  _ <- try (body *> settle)
  diagnostics <- liftEffect stop
  unless (Array.any (\d -> d.code == code) diagnostics) do
    liftEffect $ throw $ "Expected diagnostic " <> code <> ", got: " <> joinWith ", " (_.code <$> diagnostics)

-- | Lets pending microtask flushes and effects run.
settle :: Aff Unit
settle = do
  liftEffect flush
  delay (Milliseconds 0.0)
  liftEffect flush

-- | Resolves a JSX value to what it renders to, for DOM-free assertions
-- | (text children render to their string).
foreign import jsxValue :: forall jsx. jsx -> Effect String
