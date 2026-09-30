module Examples.StartMode.Footer
  ( footer
  ) where

import Prelude

import Solid.Component as Component
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (text)

footer :: Component.Component {}
footer = Component.component \_ -> pure (H.footer [ P.id "footer" ] [ text "loaded lazily" ])
