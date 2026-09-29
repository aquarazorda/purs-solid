module Solid.Start.App
  ( App
  , StartConfig
  , createApp
  , runApp
  , defaultStartConfig
  ) where

import Solid.JSX (JSX)

-- | The root view of a Start app.
newtype App = App JSX

type StartConfig =
  { basePath :: String
  , assetPrefix :: String
  , isDev :: Boolean
  }

createApp :: JSX -> App
createApp = App

runApp :: App -> JSX
runApp (App view) = view

defaultStartConfig :: StartConfig
defaultStartConfig =
  { basePath: "/"
  , assetPrefix: "/"
  , isDev: true
  }
