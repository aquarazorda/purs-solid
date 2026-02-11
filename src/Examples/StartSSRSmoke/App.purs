module Examples.StartSSRSmoke.App
  ( app
  ) where

import Prelude

import Solid.JSX as JSX
import Solid.Start.App as StartApp

app :: StartApp.App
app = StartApp.createApp (pure (JSX.text "ssr-hydration-smoke"))
