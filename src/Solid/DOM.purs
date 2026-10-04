-- | Elements take a record of props and their children:
-- |
-- | ```purescript
-- | H.div { id: "card", class: { selected: isSelected }, "data-testid": "card" }
-- |   [ H.a { href: "/docs", onClick: \_ -> track } "Docs"
-- |   , H.span {} (show <$> count)
-- |   ]
-- | ```
-- |
-- | Each field is checked against the element's row (`Solid.DOM.HTML`,
-- | `Solid.DOM.SVG`), and every attribute takes a value or an `Accessor`.
-- | Event fields (`onClick`, …) take `event -> Effect Unit`. Besides the row:
-- |
-- | - `ref`: gets the element once it's created, typed by the element
-- |   (`HTMLInputElement` on `H.input`). It runs before the element is
-- |   attached, without an owner.
-- | - `class`: a string, or a record of class toggles (`{ done: isDone }`).
-- | - `style`: CSS text, or a record of properties (`{ color: colour }`).
-- | - `bindValue` / `bindChecked`: bind a field's value or a checkbox's
-- |   checked state to a `Signal` both ways.
-- | - `innerHTML` (**not** escaped: pass only trusted or sanitized HTML) and
-- |   `textContent`: replace the children.
-- | - `role`, and the `"aria-*"` attributes in `Solid.DOM.Aria`, typed by the
-- |   spec (`"aria-expanded": isOpen`, `"aria-checked": Aria.Mixed`).
-- | - `"data-*"`: any such attribute, as a string.
-- | - `"on:name"`: any event by DOM name. Solid delegates it when it's one of
-- |   the events Solid delegates.
-- |
-- | Children are one element, text (a `String` or an `Accessor String`) or an
-- | array of elements; mix text into an array with `Solid.JSX.text`.
module Solid.DOM
  ( module Exports
  , element
  ) where

import Solid.Internal.Props (class Children, class UntypedProps, untypedElement)
import Solid.Internal.Props (class Children, class Props, class UntypedProps, targetChecked, targetValue) as Exports
import Solid.Internal.View (JSX, htmlNamespace)
import Solid.Internal.View (class ToBinding, JSX) as Exports

-- | Any tag, with unchecked fields: functions are event handlers (label them
-- | `onX`) and other values are attributes named exactly as their labels.
element :: forall props children. UntypedProps props => Children children => String -> Record props -> children -> JSX
element = untypedElement htmlNamespace
