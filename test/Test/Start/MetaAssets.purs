module Test.Start.MetaAssets
  ( run
  ) where

import Prelude

import Data.Array as Array
import Effect (Effect)
import Effect.Ref as Ref
import Solid.Router.Route.Pattern (RoutePattern(..), Segment(..))
import Solid.Router.Routing (RouteDef)
import Solid.Start.App as App
import Solid.Start.Meta as Meta
import Solid.Start.Prerender as Prerender
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

  assertEqual
    "meta renderTag escapes title markup"
    "<title>&lt;unsafe&gt;</title>"
    (Meta.renderTag (Meta.TitleTag "<unsafe>"))

  assertEqual
    "meta renderHeadHtml concatenates rendered tags"
    "<title>hello</title><meta name=\"description\" content=\"test\" />"
    (Meta.renderHeadHtml doc)

  let config = App.defaultStartConfig { basePath = "/docs", assetPrefix = "/assets" }
  assertEqual "resolveAssetUrl joins asset prefix" "/assets/main.js" (StaticAssets.resolveAssetUrl config "main.js")
  assertEqual "resolveAssetUrl trims leading slash" "/assets/main.js" (StaticAssets.resolveAssetUrl config "/main.js")
  assertEqual "resolvePublicUrl joins base path" "/docs/about" (StaticAssets.resolvePublicUrl config "about")
  assertEqual "routeToOutputPath maps root route" "index.html" (StaticAssets.routeToOutputPath "/")
  assertEqual "routeToOutputPath maps nested route" "blog/post/index.html" (StaticAssets.routeToOutputPath "/blog/post")
  assertEqual "routeToOutputPath trims trailing slash" "blog/post/index.html" (StaticAssets.routeToOutputPath "/blog/post/")

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

  assertEqual
    "prerender entries include output path mapping"
    [ { routePath: "/", outputPath: "index.html" }
    , { routePath: "/about", outputPath: "about/index.html" }
    ]
    (Prerender.entries (Prerender.fromPaths [ "/about", "/" ]))

  let manifestPaths = Prerender.paths Prerender.fromManifestRoutes
  assertEqual "prerender manifest includes story route" true (Array.elem "/stories/:id" manifestPaths)

  hooksRef <- Ref.new ([] :: Array String)
  let hooks =
        { beforeRender: \entry ->
            Ref.modify_ (_ <> [ "before:" <> entry.routePath ]) hooksRef
        , afterRender: \entry html ->
            Ref.modify_ (_ <> [ "after:" <> entry.outputPath <> ":" <> html ]) hooksRef
        }

  Prerender.runStaticExportHooks hooks { routePath: "/about", outputPath: "about/index.html" } "<html />"
  recordedHooks <- Ref.read hooksRef
  assertEqual
    "runStaticExportHooks executes before/after hook sequence"
    [ "before:/about", "after:about/index.html:<html />" ]
    recordedHooks

mkRoute :: String -> RouteDef
mkRoute routeId =
  { id: routeId
  , pattern: RoutePattern [ Static "placeholder" ]
  , moduleName: "Routes.Placeholder"
  , sourcePath: "placeholder.purs"
  }
