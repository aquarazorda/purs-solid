module Test.Start.MetaAssets
  ( run
  ) where

import Prelude

import Effect (Effect)
import Solid.Start.App as App
import Solid.Start.Meta as Meta
import Solid.Start.Prerender as Prerender
import Solid.Start.Route.Pattern (RoutePattern(..), Segment(..))
import Solid.Start.Routing (RouteDef)
import Solid.Start.StaticAssets as StaticAssets
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  let doc =
        Meta.empty
          # Meta.withTag (Meta.TitleTag "hello")
          # Meta.withTag (Meta.MetaNameTag "description" "test")

  assertEqual
    "meta tags preserve append order"
    [ Meta.TitleTag "hello", Meta.MetaNameTag "description" "test" ]
    (Meta.tags doc)

  let config = App.defaultStartConfig { basePath = "/docs", assetPrefix = "/assets" }
  assertEqual "resolveAssetUrl joins asset prefix" "/assets/main.js" (StaticAssets.resolveAssetUrl config "main.js")
  assertEqual "resolveAssetUrl trims leading slash" "/assets/main.js" (StaticAssets.resolveAssetUrl config "/main.js")
  assertEqual "resolvePublicUrl joins base path" "/docs/about" (StaticAssets.resolvePublicUrl config "about")

  let routes =
        [ mkRoute "/"
        , mkRoute "/about"
        , mkRoute "/about"
        , mkRoute "/blog/:slug"
        ]

  assertEqual
    "prerender plan deduplicates and sorts route ids"
    [ "/", "/about", "/blog/:slug" ]
    (Prerender.paths (Prerender.fromRouteDefs routes))

mkRoute :: String -> RouteDef
mkRoute routeId =
  { id: routeId
  , pattern: RoutePattern [ Static "placeholder" ]
  , moduleName: "Routes.Placeholder"
  , sourcePath: "placeholder.purs"
  }
