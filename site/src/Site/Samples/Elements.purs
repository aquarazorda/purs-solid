module Site.Samples.Elements where

import Prelude

import DOM.HTML.Indexed.InputType (InputType(..))
import Data.Tuple (fst)
import Effect (Effect)
import Solid.DOM (element)
import Solid.DOM.Aria as Aria
import Solid.DOM.HTML as H
import Solid.DOM.SVG as S
import Solid.JSX (JSX, text)
import Solid.Signal (Accessor, Signal, get)
import Web.HTML.HTMLInputElement as Input
import Web.UIEvent.KeyboardEvent as KeyboardEvent

-- region elements
card :: Accessor String -> Accessor Boolean -> JSX
card title selected =
  H.article { class: { card: true, selected }, "data-testid": "card" }
    [ H.h2 {} title
    , H.a { href: "/docs", title } "Read more"
    , H.img { src: "/logo.svg", alt: "" }
    ]

-- endregion

-- region fields
search :: Signal String -> (String -> Effect Unit) -> JSX
search query submit =
  H.div { role: "search" }
    [ H.input
        { type: InputSearch
        , "aria-label": "Search the docs"
        , bindValue: query
        , ref: Input.select
        , onKeyDown: \event ->
            when (KeyboardEvent.key event == "Enter") (get (fst query) >>= submit)
        }
    , H.p { style: { color: "gray", "font-size": "0.9em" } } "Press Enter"
    , H.div { "aria-live": Aria.Polite, innerHTML: "<b>trusted HTML only</b>" } []
    ]

-- endregion

-- region untyped
widget :: JSX
widget =
  element "my-widget" { "label-text": "Hi", onClick: \_ -> pure unit }
    [ text "content" ]

-- endregion

-- region svg
icon :: JSX
icon = S.svg { viewBox: "0 0 24 24", width: "24" }
  (S.path { d: "M4 12h16", stroke: "currentColor", strokeWidth: "2" } [])
-- endregion
