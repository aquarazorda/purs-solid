-- | View descriptions.
-- |
-- | A `JSX` value describes UI; building it does nothing. Rendering it (via a
-- | parent element, a component, control flow or `Solid.Web.render`) creates
-- | the DOM, so the same `JSX` value can be rendered in several places.
module Solid.JSX
  ( module Exports
  , text
  , reactive
  , fragment
  , empty
  ) where

import Prelude

import Solid.Internal.View (Binding(..), JSX, class ToBinding, binding, reactiveJsx, textJsx)
import Solid.Internal.View (JSX) as Exports
import Solid.Internal.View as View
import Solid.Signal (Accessor)

-- | Text, fixed (`text "Hello"`) or reactive (`text (show <$> count)`).
text :: forall v. ToBinding v String => v -> JSX
text value = case binding value of
  Static string -> textJsx string
  Dynamic accessor -> reactiveJsx (textJsx <$> accessor)

-- | A reactive region: re-renders when the accessor's value changes. Prefer
-- | control flow (`Solid.Control`) for conditionals and lists; it reuses DOM.
reactive :: Accessor JSX -> JSX
reactive = reactiveJsx

-- | Several nodes without a wrapper element.
fragment :: Array JSX -> JSX
fragment = View.fragment

-- | Renders nothing.
empty :: JSX
empty = View.empty
