module Examples.SolidStart.App
  ( app
  ) where

import Effect (Effect)

import Solid.Component as Component
import Solid.DOM as DOM
import Solid.Start.App as StartApp

root :: Component.Component {}
root = Component.component \_ -> do
  pure $ DOM.div { className: "start-scaffold" }
    [ DOM.text "SolidStart scaffold app"
    ]

app :: StartApp.App
app = StartApp.createApp (pure (Component.element root {}))
