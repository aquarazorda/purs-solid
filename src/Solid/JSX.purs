-- | A `JSX` value describes UI; building it does nothing. Each place it's
-- | rendered creates its own DOM.
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

-- | Re-renders when the accessor changes. Prefer `Solid.Control` for
-- | conditionals and lists; it reuses DOM.
reactive :: Accessor JSX -> JSX
reactive = reactiveJsx

fragment :: Array JSX -> JSX
fragment = View.fragment

empty :: JSX
empty = View.empty
