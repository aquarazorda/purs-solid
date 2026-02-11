module Examples.SolidStart.Entry.ServerMain
  ( renderDocumentForRoute
  , prerenderEntries
  , renderPrerenderEntry
  ) where

import Data.Either (Either)
import Effect (Effect)
import Prelude

import Examples.SolidStart as Example
import Solid.Component as Component
import Solid.Start.App as StartApp
import Solid.Start.Entry.Server as ServerEntry
import Solid.Start.Error (StartError)
import Solid.Start.Meta as Meta
import Solid.Start.Prerender as Prerender

renderDocumentForRoute :: String -> Effect (Either StartError String)
renderDocumentForRoute routePath =
  ServerEntry.renderDocumentHtmlWithAssets
    StartApp.defaultStartConfig
    (routeMeta routePath)
    [ "/dist/examples/solid-start.js" ]
    app
  where
  app = StartApp.createApp (pure (Component.element (Example.appWithRoute routePath) {}))

prerenderEntries :: Array Prerender.PrerenderEntry
prerenderEntries =
  Prerender.entries Prerender.fromManifestRoutes

renderPrerenderEntry :: Prerender.PrerenderEntry -> Effect (Either StartError String)
renderPrerenderEntry entry =
  renderDocumentForRoute entry.routePath

routeMeta :: String -> Meta.MetaDoc
routeMeta routePath =
  Meta.fromTitle ("purs-solid SolidStart Example - " <> routePath)
    `Meta.merge` Meta.withTag (Meta.MetaNameTag "description" "purs-solid SolidStart route") Meta.empty
