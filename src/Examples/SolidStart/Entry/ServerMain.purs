module Examples.SolidStart.Entry.ServerMain
  ( renderDocumentForRoute
  ) where

import Data.Either (Either)
import Effect (Effect)
import Prelude

import Examples.SolidStart as Example
import Solid.Component as Component
import Solid.Start.App as StartApp
import Solid.Start.Entry.Server as ServerEntry
import Solid.Start.Error (StartError)

renderDocumentForRoute :: String -> Effect (Either StartError String)
renderDocumentForRoute routePath =
  ServerEntry.renderDocumentHtml app
  where
  app = StartApp.createApp (pure (Component.element (Example.appWithRoute routePath) {}))
