-- | Helpers for testing views in a DOM (a browser, or happy-dom / jsdom).
-- | Diagnostics need Solid's dev build (the `development` export condition).
module Solid.Testing
  ( settle
  , Mounted
  , mount
  , mountUsing
  , html
  , query
  , click
  , inputText
  , Diagnostic
  , collectDiagnostics
  , ignoreDiagnostic
  ) where

import Prelude

import Data.Either (Either, either)
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), maybe)
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), delay, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (Error, throw)
import Solid.Internal.View (JSX)
import Solid.Reactivity (flush)
import Solid.Web as Web
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

-- | Applies pending writes, lets queued work run, and applies what it wrote.
settle :: Aff Unit
settle = do
  liftEffect flush
  delay (Milliseconds 0.0)
  liftEffect flush

type Mounted = { root :: Element, dispose :: Effect Unit }

-- | Renders into a fresh container appended to `document.body`. `dispose`
-- | unmounts it and removes the container.
mount :: JSX -> Aff Mounted
mount = mountUsing Web.render

-- | `mount` with another render function, e.g. `Solid.Web.renderWith options`.
mountUsing :: (JSX -> Element -> Effect (Either Error (Effect Unit))) -> JSX -> Aff Mounted
mountUsing render view = do
  container <- liftEffect do
    doc <- document =<< window
    container <- createElement "div" (HTMLDocument.toDocument doc)
    body <- HTMLDocument.body doc
    for_ body \b -> appendChild (toNode container) (HTMLElement.toNode b)
    pure container
  dispose <- liftEffect (render view container) >>= either throwError pure
  settle
  pure { root: container, dispose: dispose *> remove (toChildNode container) }

-- | The container's HTML once settled.
html :: Mounted -> Aff String
html mounted = settle *> liftEffect (innerHTML mounted.root)

foreign import innerHTML :: Element -> Effect String

query :: String -> Mounted -> Aff (Maybe Element)
query selector mounted = liftEffect (querySelector (QuerySelector selector) (toParentNode mounted.root))

click :: Element -> Effect Unit
click element = maybe (throw "not an HTML element") HTMLElement.click (HTMLElement.fromElement element)

-- | Sets an input's value and dispatches an `input` event.
inputText :: String -> Element -> Effect Unit
inputText value element = case HTMLInputElement.fromElement element of
  Nothing -> throw "not an input"
  Just input -> do
    HTMLInputElement.setValue value input
    event <- inputEvent
    void (dispatchEvent event (toEventTarget element))

foreign import inputEvent :: Effect Event

type Diagnostic = { code :: String, severity :: String, message :: String }

-- | Starts collecting Solid's diagnostics; the returned effect stops and
-- | returns them.
foreign import collectDiagnostics :: Effect (Effect (Array Diagnostic))

-- | Drops diagnostics with this code from every running collection, e.g.
-- | once a test has checked that it was reported.
foreign import ignoreDiagnostic :: String -> Effect Unit
