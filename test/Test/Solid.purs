-- | Test helpers for Solid 2 semantics.
module Test.Solid
  ( solidIt
  , settle
  , expectDiagnostic
  , jsxValue
  , refEq
  , Mounted
  , mount
  , html
  , query
  , click
  , inputText
  , attribute
  , namespaceOf
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
import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Solid.JSX (JSX)
import Solid.Reactivity (flush)
import Solid.Web as Web
import Web.DOM.Element (Element)
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

-- | Reference equality (`===`), for asserting identity is preserved.
foreign import refEq :: forall a. a -> a -> Boolean

type Mounted = { root :: Element, dispose :: Effect Unit }

-- | Renders `view` into a fresh container attached to `document.body`.
mount :: JSX -> Aff Mounted
mount view = do
  container <- liftEffect createContainer
  result <- liftEffect (Web.render view container)
  dispose <- either (liftEffect <<< throw <<< show) pure result
  settle
  pure { root: container, dispose: dispose *> removeContainer container }

foreign import createContainer :: Effect Element
foreign import removeContainer :: Element -> Effect Unit

-- | The container's inner HTML (after letting pending updates apply).
html :: Mounted -> Aff String
html mounted = settle *> liftEffect (innerHtml mounted.root)

foreign import innerHtml :: Element -> Effect String

query :: String -> Mounted -> Aff (Maybe Element)
query selector mounted = liftEffect (toMaybe <$> querySelectorImpl selector mounted.root)

foreign import querySelectorImpl :: String -> Element -> Effect (Nullable Element)

-- | Dispatches a bubbling click (reaches Solid's delegated handlers).
foreign import click :: Element -> Effect Unit

-- | Sets an input's value and dispatches a bubbling `input` event.
foreign import inputText :: String -> Element -> Effect Unit

attribute :: String -> Element -> Effect (Maybe String)
attribute name element = toMaybe <$> attributeImpl name element

foreign import attributeImpl :: String -> Element -> Effect (Nullable String)

foreign import namespaceOf :: Element -> Effect String
