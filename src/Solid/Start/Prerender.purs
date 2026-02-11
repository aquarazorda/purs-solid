module Solid.Start.Prerender
  ( PrerenderPlan
  , fromRouteDefs
  , fromPaths
  , paths
  ) where

import Data.Array as Array
import Prelude

import Solid.Start.Routing (RouteDef)

newtype PrerenderPlan = PrerenderPlan (Array String)

derive instance eqPrerenderPlan :: Eq PrerenderPlan

instance showPrerenderPlan :: Show PrerenderPlan where
  show (PrerenderPlan values) = "PrerenderPlan " <> show values

fromRouteDefs :: Array RouteDef -> PrerenderPlan
fromRouteDefs routeDefs =
  fromPaths (map _.id routeDefs)

fromPaths :: Array String -> PrerenderPlan
fromPaths routePaths =
  PrerenderPlan (Array.sort (Array.nub routePaths))

paths :: PrerenderPlan -> Array String
paths (PrerenderPlan routePaths) = routePaths
