module Test.Start.Routing
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Exception (throw)
import Solid.Router.Route.Params (toArray)
import Solid.Router.Route.Pattern (RoutePattern(..), Segment(..))
import Solid.Router.Routing (MatchError(..), RouteDef, RouteMatch, matchPathIn)
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  assertEqual
    "matchPathIn returns NoMatch when route table is empty"
    (Left (NoMatch "/"))
    (matchPathIn [] "/")

  root <- expectMatch "root route matches slash" [ routeRoot ] "/"
  assertEqual "root route id" "/" root.route.id
  assertEqual "root route params" ([] :: Array (String /\ String)) (toArray root.params)

  about <- expectMatch "static route matches exact path" [ routeAbout ] "/about"
  assertEqual "about route id" "/about" about.route.id

  slug <- expectMatch "param route captures slug" [ routeBlogSlug ] "/blog/solid-start"
  assertEqual "blog param route id" "/blog/:slug" slug.route.id
  assertEqual
    "blog param value"
    [ "slug" /\ "solid-start" ]
    (toArray slug.params)

  staticOverParam <- expectMatch
    "static route outranks param route"
    [ routeBlogSlug, routeBlogNew ]
    "/blog/new"
  assertEqual "static route selected" "/blog/new" staticOverParam.route.id

  paramOverCatchAll <- expectMatch
    "param route outranks catch-all on single segment"
    [ routeDocsCatchAll, routeDocsId ]
    "/docs/intro"
  assertEqual "param route selected" "/docs/:id" paramOverCatchAll.route.id
  assertEqual
    "docs param captured"
    [ "id" /\ "intro" ]
    (toArray paramOverCatchAll.params)

  catchAll <- expectMatch
    "catch-all route captures remaining path"
    [ routeDocsCatchAll ]
    "/docs/guides/routing"
  assertEqual "catch-all route id" "/docs/*parts" catchAll.route.id
  assertEqual
    "catch-all captured joined path"
    [ "parts" /\ "guides/routing" ]
    (toArray catchAll.params)

  optionalConsumed <- expectMatch
    "optional segment consumes when provided"
    [ routeLangAbout ]
    "/en/about"
  assertEqual "optional route id" "/:lang?/about" optionalConsumed.route.id
  assertEqual
    "optional segment captured"
    [ "lang" /\ "en" ]
    (toArray optionalConsumed.params)

  optionalSkipped <- expectMatch
    "plain static route outranks skipped optional route"
    [ routeLangAbout, routeAbout ]
    "/about"
  assertEqual "static route wins over skipped optional" "/about" optionalSkipped.route.id
  assertEqual "static route params empty" ([] :: Array (String /\ String)) (toArray optionalSkipped.params)

  aboutWithQuery <- expectMatch
    "matcher strips query and fragment"
    [ routeAbout ]
    "/about?from=nav#details"
  assertEqual "about route with query id" "/about" aboutWithQuery.route.id

  aboutTrailing <- expectMatch
    "trailing slash is ignored for segment matching"
    [ routeAbout ]
    "/about/"
  assertEqual "about route with trailing slash id" "/about" aboutTrailing.route.id

expectMatch :: String -> Array RouteDef -> String -> Effect RouteMatch
expectMatch label routes path =
  case matchPathIn routes path of
    Left errorValue ->
      throw (label <> ": expected match, got " <> show errorValue)
    Right routeMatch ->
      pure routeMatch

routeRoot :: RouteDef
routeRoot =
  { id: "/"
  , pattern: RoutePattern []
  , moduleName: "Routes.Index"
  , sourcePath: "index.purs"
  }

routeAbout :: RouteDef
routeAbout =
  { id: "/about"
  , pattern: RoutePattern [ Static "about" ]
  , moduleName: "Routes.About"
  , sourcePath: "about.purs"
  }

routeBlogSlug :: RouteDef
routeBlogSlug =
  { id: "/blog/:slug"
  , pattern: RoutePattern [ Static "blog", Param "slug" ]
  , moduleName: "Routes.Blog.Slug"
  , sourcePath: "blog/[slug].purs"
  }

routeBlogNew :: RouteDef
routeBlogNew =
  { id: "/blog/new"
  , pattern: RoutePattern [ Static "blog", Static "new" ]
  , moduleName: "Routes.Blog.New"
  , sourcePath: "blog/new.purs"
  }

routeDocsId :: RouteDef
routeDocsId =
  { id: "/docs/:id"
  , pattern: RoutePattern [ Static "docs", Param "id" ]
  , moduleName: "Routes.Docs.Id"
  , sourcePath: "docs/[id].purs"
  }

routeDocsCatchAll :: RouteDef
routeDocsCatchAll =
  { id: "/docs/*parts"
  , pattern: RoutePattern [ Static "docs", CatchAll "parts" ]
  , moduleName: "Routes.Docs.Parts"
  , sourcePath: "docs/[...parts].purs"
  }

routeLangAbout :: RouteDef
routeLangAbout =
  { id: "/:lang?/about"
  , pattern: RoutePattern [ Optional "lang", Static "about" ]
  , moduleName: "Routes.Lang.About"
  , sourcePath: "[[lang]]/about.purs"
  }
