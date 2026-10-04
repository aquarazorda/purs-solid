module Site.Pages
  ( Snippets
  , landing
  , docs
  ) where

import Prelude

import Data.Array (concatMap)
import Site.Toc (Section(..), sectionId, sectionTitle, sections)
import Solid.DOM.HTML as H
import Solid.JSX (JSX, text)

-- | A sample's region name to its highlighted HTML (see `site/build.mjs`).
type Snippets = String -> String

repo :: String
repo = "https://github.com/aquarazorda/purs-solid"

sample :: Snippets -> String -> JSX
sample snippets name = H.pre { class: "code" } (H.code { innerHTML: snippets name } [])

plain :: String -> JSX
plain source = H.pre { class: "code" } (H.code {} source)

c :: String -> JSX
c = H.code {}

header :: String -> JSX
header root = H.header { class: "top" }
  [ H.a { class: "brand", href: root <> "./" } [ H.span { class: "mark" } "λ", text "purs-solid" ]
  , H.nav {}
      [ H.a { href: root <> "docs/" } "Docs"
      , H.a { href: root <> "api/index.html" } "API"
      , H.a { href: repo } "GitHub"
      ]
  ]

footer :: String -> JSX
footer root = H.footer { class: "bottom" }
  [ H.p {}
      [ text "purs-solid · ISC license · "
      , H.a { href: repo } "GitHub"
      , text " · "
      , H.a { href: root <> "api/index.html" } "API reference"
      ]
  ]

landing :: Snippets -> String -> JSX
landing snippets demo = H.div { class: "page" }
  [ header ""
  , H.main {}
      [ H.section { class: "hero" }
          [ H.p { class: "eyebrow" } "PureScript bindings for Solid 2"
          , H.h1 {} "Fine-grained reactivity, checked by the compiler."
          , H.p { class: "lead" }
              "Signals, stores, async data, server rendering and hydration, a typed router and start mode, through Solid's public API. The types reject code that would misbehave at runtime."
          , H.div { class: "actions" }
              [ H.a { class: "button primary", href: "docs/" } "Read the docs"
              , H.a { class: "button", href: repo } "View on GitHub"
              ]
          ]
      , H.section { class: "demo" }
          [ H.div { class: "demo-code" } (sample snippets "counter")
          , H.div { class: "demo-live" }
              [ H.p { class: "caption" } "Rendered at build time, hydrated in your browser:"
              , H.div { id: "demo", innerHTML: demo } []
              ]
          ]
      , H.section { class: "features" }
          [ H.h2 {} "What the compiler catches"
          , H.div { class: "grid" } (feature snippets <$> features)
          ]
      , H.section { class: "closing" }
          [ H.h2 {} "Solid underneath"
          , H.p {}
              "With compileViews in the Vite plugin, views go through Solid's own compiler, into the same templates as Solid JSX, and render about as fast. Without it, purs-solid clones templates at runtime: updates cost the same, and creating DOM is about 1.35× slower."
          , H.a { class: "button primary", href: "docs/" } "Get started"
          ]
      ]
  , footer ""
  ]

type Feature = { title :: String, body :: String, snippet :: String }

features :: Array Feature
features =
  [ { title: "Props checked per element"
    , body: "Each field is checked against the element's attributes and events. Every attribute takes a value or an accessor."
    , snippet: "feature-props"
    }
  , { title: "Setup can't write"
    , body: "Components run in Setup, which creates signals, memos and effects. Writes happen in handlers, in Effect."
    , snippet: "feature-setup"
    }
  , { title: "Async can't be read early"
    , body: "createAsync gives an Async with no get: render it, derive from it or await it, and loading shows a fallback."
    , snippet: "feature-async"
    }
  , { title: "Routes typed by their path"
    , body: "A route's params come from its pattern, :id<int> arrives as an Int, and href builds links from the same pattern."
    , snippet: "feature-routes"
    }
  , { title: "ARIA from the spec"
    , body: "aria-* attributes follow WAI-ARIA 1.2: booleans, numbers, and a type for each set of keywords."
    , snippet: "feature-aria"
    }
  , { title: "Server code stays on the server"
    , body: "In start mode a server module's functions never reach the browser, and what crosses the wire must be Serializable."
    , snippet: "server-function"
    }
  ]

feature :: Snippets -> Feature -> JSX
feature snippets { title, body, snippet } = H.article { class: "feature" }
  [ H.h3 {} title, H.p {} body, sample snippets snippet ]

type Guide = { modules :: Array String, content :: Array JSX }

docs :: Snippets -> String -> JSX
docs snippets contents = H.div { class: "page" }
  [ header "../"
  , H.div { class: "docs" }
      [ H.nav { id: "toc", class: "toc", "aria-label": "Contents", innerHTML: contents } []
      , H.main {} (concatMap section sections)
      ]
  , footer "../"
  ]
  where
  section current =
    let
      id = sectionId current
      { modules, content } = guide snippets current
    in
      [ H.section { id, class: "doc" } $
          [ H.h2 {} (H.a { href: "#" <> id } (sectionTitle current)) ] <> content <> api modules
      ]

  api [] = []
  api modules =
    [ H.p { class: "api" } $ [ text "API: " ] <> concatMap
        (\name -> [ H.a { href: "../api/" <> name <> ".html" } (c name), text " " ])
        modules
    ]

guide :: Snippets -> Section -> Guide
guide snippets = case _ of
  Install ->
    { modules: []
    , content:
        [ H.p {} "Solid 2 is a release candidate, so pin exact versions. The router and meta packages are needed only for Solid.Router and Solid.Meta, and the Vite plugin only for start mode."
        , plain "npm install --save-exact solid-js@2.0.0-rc.13 @solidjs/web@2.0.0-rc.13\nnpm install --save-exact @solidjs/router@2.0.0-next.32 @solidjs/meta@1.0.0-next.2\nnpm install --save-dev --save-exact @solidjs/vite-plugin@3.0.0-next.47"
        , H.p {} "Add the package to your Spago workspace from Git, pinned to a commit:"
        , plain "workspace:\n  extraPackages:\n    purs-solid:\n      git: https://github.com/aquarazorda/purs-solid.git\n      ref: <commit>"
        , H.p {} [ text "Bundle development builds with the ", c "development", text " export condition to get Solid's diagnostics." ]
        ]
    }
  Components ->
    { modules: [ "Solid.Component", "Solid.DOM", "Solid.DOM.HTML", "Solid.DOM.SVG", "Solid.DOM.Aria", "Solid.JSX" ]
    , content:
        [ H.p {} [ text "A ", c "Component", text " is a function from a props record to a view, built in ", c "Setup", text ". Elements take a record of props and their children; ", c "Component.element", text " renders a component with its props." ]
        , sample snippets "counter"
        , H.p {} [ text "Each field is checked against the element's row, so ", c "href", text " only type-checks on elements that have it. Attributes take a value or an ", c "Accessor", text "; event fields take a handler for the row's event type. Children are one element, text (a ", c "String", text " or an ", c "Accessor String", text "), or an array of elements; mix text into an array with ", c "text", text ". Void elements like ", c "H.img", text " take only the record." ]
        , sample snippets "elements"
        , H.p {} "Beyond the element's own attributes, a record can have:"
        , H.ul {}
            [ H.li {} [ c "ref", text ": gets the element once it's created, typed by the element." ]
            , H.li {} [ c "class", text ": a string, or a record of class toggles." ]
            , H.li {} [ c "style", text ": CSS text, or a record of properties." ]
            , H.li {} [ c "bindValue", text " / ", c "bindChecked", text ": bind a field's value or a checkbox to a signal both ways." ]
            , H.li {} [ c "role", text " and the ", c "aria-*", text " attributes, typed by WAI-ARIA 1.2 (", c "Solid.DOM.Aria", text ")." ]
            , H.li {} [ c "data-*", text " attributes, ", c "on:name", text " for any event, and ", c "innerHTML", text " / ", c "textContent", text "." ]
            ]
        , sample snippets "fields"
        , H.p {} [ text "SVG elements live in ", c "Solid.DOM.SVG", text ". For custom elements, ", c "element", text " takes any tag and unchecked fields: functions are handlers, everything else is an attribute." ]
        , sample snippets "svg"
        , sample snippets "untyped"
        ]
    }
  Reactivity ->
    { modules: [ "Solid.Signal", "Solid.Reactivity", "Solid.Setup", "Solid.Lifecycle", "Solid.Context" ]
    , content:
        [ H.p {} [ text "Component bodies run in ", c "Setup", text ": they create signals, memos and effects, but can't read or write signals directly. ", c "get", text ", ", c "set", text " and ", c "modify", text " run in ", c "Effect", text ", in handlers and in an effect's apply step. Derived values are ", c "Accessor", text "s, a lawful monad with no effects." ]
        , sample snippets "signals"
        , H.p {} [ text "An effect splits into a tracked compute (an ", c "Accessor", text ") and an untracked apply, which returns its cleanup. Props are plain records; pass reactive values as ", c "Accessor", text " fields. ", c "liftSetup", text " is the escape hatch for running an ", c "Effect", text " in setup." ]
        ]
    }
  ControlFlow ->
    { modules: [ "Solid.Control" ]
    , content:
        [ H.p {} [ text "Views are descriptions: hidden branches are never built. ", c "when", text ", ", c "showMaybe", text " and the list functions reuse DOM as their inputs change. A list of records is keyed by a field, so a rebuilt array doesn't rebuild its rows." ]
        , sample snippets "control"
        , H.p {} [ c "caseOn", text " switches on a data type and rebuilds a branch only when the key changes, here the constructor." ]
        , sample snippets "case"
        ]
    }
  Stores ->
    { modules: [ "Solid.Store" ]
    , content:
        [ H.p {} [ text "Stores hold nested state. Updates are pure ", c "Update", text " values on typed paths, applied to Solid's draft; reads go through cursors, so each row only tracks the fields it shows." ]
        , sample snippets "store"
        ]
    }
  Async ->
    { modules: [ "Solid.Async", "Solid.Action" ]
    , content:
        [ H.p {} [ c "createAsync", text " runs an ", c "Aff", text " for each value of its input and kills superseded ones. The result is an ", c "Async", text ", which may not have loaded, so it has no ", c "get", text ": render it, derive from it, or await it with ", c "resolve", text ". ", c "loading", text " shows a fallback until it's ready, and ", c "errored", text " catches failures." ]
        , sample snippets "async"
        , H.p {} [ text "Mutations are ", c "Action", text "s (", c "Solid.Action", text "), and optimistic values exist only inside them." ]
        ]
    }
  Router ->
    { modules: [ "Solid.Router", "Solid.Router.Path", "Solid.Router.Search", "Solid.Router.Query", "Solid.Router.Action" ]
    , content:
        [ H.p {} [ text "Paths are parsed at compile time: ", c "route @\"/users/:id<int>\"", text " gives its component ", c "{ id :: Int }", text ", and ", c "href", text " builds links from the same pattern. Links are plain anchors that the router intercepts. Search params are typed by a row." ]
        , sample snippets "router"
        , H.p {} [ c "Solid.Router.Query", text " caches route data, and ", c "Solid.Router.Action", text " runs mutations the router tracks: forms, submissions and revalidation." ]
        ]
    }
  Ssr ->
    { modules: [ "Solid.Web", "Solid.Web.SSR", "Solid.Meta", "Solid.Errors" ]
    , content:
        [ H.p {} [ text "Render on the server with ", c "renderToString", text ", ", c "renderToStringAsync", text " (waits for async data) or ", c "renderToReadableStream", text ", then hydrate the same view on the client. Async values resolved on the server are serialized, so the client doesn't fetch them again. Head tags from ", c "Solid.Meta", text " can be rendered anywhere." ]
        , sample snippets "ssr"
        ]
    }
  StartMode ->
    { modules: [ "Solid.Start.ServerFunction", "Solid.Start.UseServer", "Solid.Start.Response", "Solid.Start.Middleware" ]
    , content:
        [ H.p {} [ text "A start-mode app is a ", c "Component", text ". Use ", c "purs-solid/vite", text " in place of ", c "@solidjs/vite-plugin", text ": it takes the same options, with ", c "start.app", text " and ", c "start.middleware", text " given as module names. ", c "compileViews: true", text " compiles views with Solid's compiler into the same templates as Solid JSX; element calls it can't read stay on the runtime path." ]
        , plain "import solid from \"purs-solid/vite\";\n\nexport default defineConfig({ plugins: [solid({ start: true, ssr: true, compileViews: true })] });"
        , H.p {} [ text "Server functions live in a server module that re-exports ", c "Solid.Start.UseServer", text ". None of its code reaches the browser; every export is a ", c "serverFunction", text ", with ", c "Serializable", text " arguments and results. Call them with ", c "call", text ", ", c "queryServer", text " or ", c "serverAction", text "." ]
        , sample snippets "server-function"
        ]
    }
  Testing ->
    { modules: [ "Solid.Testing" ]
    , content:
        [ H.p {} [ c "Solid.Testing", text " mounts views into a DOM (happy-dom works) and waits for Solid to settle. It doesn't depend on a test framework." ]
        , sample snippets "testing"
        ]
    }
