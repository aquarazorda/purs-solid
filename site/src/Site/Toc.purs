module Site.Toc
  ( Section(..)
  , sections
  , sectionId
  , sectionTitle
  , toc
  ) where

import Prelude

import Data.Array (filter, last, zip)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Traversable (for)
import Data.Tuple (Tuple(..), fst)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Component as Component
import Solid.DOM.Aria as Aria
import Solid.DOM.HTML as H
import Solid.JSX (fragment)
import Solid.Lifecycle (onSettled)
import Solid.Signal (createSignal, set)
import Web.DOM.Document (documentElement)
import Web.DOM.Element (getBoundingClientRect, scrollHeight)
import Web.DOM.NonElementParentNode (getElementById)
import Web.Event.Event (EventType(..))
import Web.Event.EventTarget (addEventListener, eventListener, removeEventListener)
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.Window (document, innerHeight, scrollY, toEventTarget)

data Section = Install | Components | Reactivity | ControlFlow | Stores | Async | Router | Ssr | StartMode | Testing

derive instance Eq Section

sections :: Array Section
sections = [ Install, Components, Reactivity, ControlFlow, Stores, Async, Router, Ssr, StartMode, Testing ]

sectionId :: Section -> String
sectionId = case _ of
  Install -> "install"
  Components -> "components"
  Reactivity -> "reactivity"
  ControlFlow -> "control-flow"
  Stores -> "stores"
  Async -> "async"
  Router -> "router"
  Ssr -> "ssr"
  StartMode -> "start-mode"
  Testing -> "testing"

sectionTitle :: Section -> String
sectionTitle = case _ of
  Install -> "Install"
  Components -> "Components and elements"
  Reactivity -> "Signals, memos and effects"
  ControlFlow -> "Control flow"
  Stores -> "Stores"
  Async -> "Async data"
  Router -> "Router"
  Ssr -> "Server rendering and hydration"
  StartMode -> "Start mode"
  Testing -> "Testing"

-- | The guide's contents, marking the section being read.
toc :: Component.Component {}
toc = Component.component \_ -> do
  current /\ setCurrent <- createSignal Install
  onSettled do
    let update = reading >>= set setCurrent
    listener <- eventListener (const update)
    target <- toEventTarget <$> window
    addEventListener scroll listener false target
    update
    pure (removeEventListener scroll listener false target)
  pure $ fragment
    [ H.p {} "Guide"
    , H.ol {} $ sections <#> \section ->
        H.li {} $ H.a
          { href: "#" <> sectionId section
          , class: { active: (_ == section) <$> current }
          , "aria-current": (\open -> if open == section then Aria.Location else Aria.NotCurrent) <$> current
          }
          (sectionTitle section)
    ]
  where
  scroll = EventType "scroll"

-- | The last section whose top has scrolled under the header, or the last
-- | section once the page is scrolled to the bottom.
reading :: Effect Section
reading = do
  win <- window
  doc <- document win
  bottom <- (\y height -> y + toNumber height) <$> scrollY win <*> innerHeight win
  total <- documentElement (HTMLDocument.toDocument doc) >>= maybe (pure 0.0) scrollHeight
  tops <- for sections \section ->
    getElementById (sectionId section) (HTMLDocument.toNonElementParentNode doc)
      >>= maybe (pure Nothing) (map (Just <<< _.top) <<< getBoundingClientRect)
  let passed = fst <$> filter (\(Tuple _ top) -> maybe false (_ <= 96.0) top) (zip sections tops)
  pure
    if bottom >= total - 2.0 then fromMaybe Install (last sections)
    else fromMaybe Install (last passed)
