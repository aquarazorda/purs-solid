module Test.Solid
  ( solidIt
  , settle
  , expectDiagnostic
  , jsxValue
  , Mounted
  , mount
  , html
  , query
  , click
  , inputText
  ) where

import Prelude

import Control.Monad.Error.Class (throwError, try)
import Data.Array as Array
import Data.Either (either)
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), maybe)
import Data.String (joinWith)
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.JSX (JSX)
import Solid.Reactivity (flush)
import Solid.Web as Web
import Test.Spec (Spec, it)
import Web.DOM.ChildNode (remove)
import Web.DOM.Document (createElement)
import Web.DOM.Element (Element, toChildNode, toEventTarget, toNode, toParentNode)
import Web.DOM.Node (appendChild)
import Web.DOM.ParentNode (QuerySelector(..), querySelector)
import Web.Event.Event (Event)
import Web.Event.EventTarget (dispatchEvent)
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.HTMLElement as HTMLElement
import Web.HTML.HTMLInputElement as HTMLInputElement
import Web.HTML.Window (document)

type Diagnostic = { code :: String, severity :: String, message :: String }

foreign import collectDiagnostics :: Effect (Effect (Array Diagnostic))

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

settle :: Aff Unit
settle = do
  liftEffect flush
  delay (Milliseconds 0.0)
  liftEffect flush

foreign import jsxValue :: JSX -> Effect String

type Mounted = { root :: Element, dispose :: Effect Unit }

mount :: JSX -> Aff Mounted
mount view = do
  container <- liftEffect do
    doc <- document =<< window
    container <- createElement "div" (HTMLDocument.toDocument doc)
    body <- HTMLDocument.body doc
    for_ body \b -> appendChild (toNode container) (HTMLElement.toNode b)
    pure container
  dispose <- liftEffect (Web.render view container) >>= either throwError pure
  settle
  pure { root: container, dispose: dispose *> remove (toChildNode container) }

html :: Mounted -> Aff String
html mounted = settle *> liftEffect (innerHTML mounted.root)

foreign import innerHTML :: Element -> Effect String

query :: String -> Mounted -> Aff (Maybe Element)
query selector mounted = liftEffect (querySelector (QuerySelector selector) (toParentNode mounted.root))

click :: Element -> Effect Unit
click element = maybe (throw "not an HTML element") HTMLElement.click (HTMLElement.fromElement element)

inputText :: String -> Element -> Effect Unit
inputText value element = case HTMLInputElement.fromElement element of
  Nothing -> throw "not an input"
  Just input -> do
    HTMLInputElement.setValue value input
    event <- inputEvent
    void (dispatchEvent event (toEventTarget element))

foreign import inputEvent :: Effect Event
