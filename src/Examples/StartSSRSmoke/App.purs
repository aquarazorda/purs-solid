module Examples.StartSSRSmoke.App
  ( app
  ) where


import Solid.JSX as JSX
import Solid.Start.App as StartApp

app :: StartApp.App
app = StartApp.createApp ((JSX.text "ssr-hydration-smoke"))
