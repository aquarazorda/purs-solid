-- | A `JSX` value describes UI; building it does nothing. Each place it's
-- | rendered creates its own DOM.
module Solid.JSX
  ( module Exports
  , text
  , reactive
  , fragment
  , empty
  ) where

import Solid.Internal.View (JSX, class ToBinding, reactiveJsx, textBinding)
import Solid.Internal.View (JSX) as Exports
import Solid.Internal.View as View
import Solid.Signal (Accessor)

-- | Text, fixed (`text "Hello"`) or reactive (`text (show <$> count)`).
text :: forall v. ToBinding v String => v -> JSX
text = textBinding

-- | Re-renders when the accessor changes. Prefer `Solid.Control` for
-- | conditionals and lists; it reuses DOM.
reactive :: Accessor JSX -> JSX
reactive = reactiveJsx

fragment :: Array JSX -> JSX
fragment = View.fragment

empty :: JSX
empty = View.empty
