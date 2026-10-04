module Examples.StartMode.Footer
  ( footer
  ) where

import Prelude

import Solid.Component as Component
import Solid.DOM.HTML as H

footer :: Component.Component {}
footer = Component.component \_ -> pure (H.footer { id: "footer" } "loaded lazily")
