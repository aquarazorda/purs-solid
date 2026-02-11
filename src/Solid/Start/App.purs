module Solid.Start.App
  ( App
  , StartConfig
  , createApp
  , runApp
  , defaultStartConfig
  ) where

import Effect (Effect)

import Solid.JSX (JSX)

newtype App = App (Effect JSX)

type StartConfig =
  { basePath :: String
  , assetPrefix :: String
  , isDev :: Boolean
  }

createApp :: Effect JSX -> App
createApp renderApp = App renderApp

runApp :: App -> Effect JSX
runApp (App renderApp) = renderApp

defaultStartConfig :: StartConfig
defaultStartConfig =
  { basePath: "/"
  , assetPrefix: "/"
  , isDev: true
  }
