module Solid.Start.Prerender
  ( PrerenderPlan
  , PrerenderEntry
  , StaticExportHooks
  , fromRouteDefs
  , fromManifestRoutes
  , fromPaths
  , paths
  , entries
  , defaultStaticExportHooks
  , runStaticExportHooks
  ) where

import Data.Array as Array
import Effect (Effect)
import Prelude

import Solid.Router.Routing (RouteDef)
import Solid.Router.Routing.Manifest as Manifest
import Solid.Start.StaticAssets as StaticAssets

newtype PrerenderPlan = PrerenderPlan (Array String)

type PrerenderEntry =
  { routePath :: String
  , outputPath :: String
  }

type StaticExportHooks =
  { beforeRender :: PrerenderEntry -> Effect Unit
  , afterRender :: PrerenderEntry -> String -> Effect Unit
  }

derive instance eqPrerenderPlan :: Eq PrerenderPlan

instance showPrerenderPlan :: Show PrerenderPlan where
  show (PrerenderPlan values) = "PrerenderPlan " <> show values

fromRouteDefs :: Array RouteDef -> PrerenderPlan
fromRouteDefs routeDefs =
  fromPaths (map _.id routeDefs)

fromManifestRoutes :: PrerenderPlan
fromManifestRoutes =
  fromRouteDefs Manifest.routes

fromPaths :: Array String -> PrerenderPlan
fromPaths routePaths =
  PrerenderPlan (Array.sort (Array.nub routePaths))

paths :: PrerenderPlan -> Array String
paths (PrerenderPlan routePaths) = routePaths

entries :: PrerenderPlan -> Array PrerenderEntry
entries (PrerenderPlan routePaths) =
  map
    (\routePath ->
      { routePath
      , outputPath: StaticAssets.routeToOutputPath routePath
      }
    )
    routePaths

defaultStaticExportHooks :: StaticExportHooks
defaultStaticExportHooks =
  { beforeRender: \_ -> pure unit
  , afterRender: \_ _ -> pure unit
  }

runStaticExportHooks :: StaticExportHooks -> PrerenderEntry -> String -> Effect Unit
runStaticExportHooks hooks entry html = do
  _ <- hooks.beforeRender entry
  hooks.afterRender entry html
