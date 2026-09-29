# purs-solid

`purs-solid` is a PureScript-first wrapper around Solid's fine-grained reactivity and rendering runtime.

This repository is a library project, not an app template. It provides typed PureScript modules backed by a small JavaScript FFI layer to expose Solid behavior in a Solid-native way.

## What this project is trying to do

- Keep Solid's mental model (signals, memos, effects, roots, control-flow primitives).
- Expose those primitives with explicit PureScript types.
- Model recoverable failures with `Either`/`Maybe` at public boundaries.
- Reuse existing PureScript web platform packages instead of re-implementing browser APIs.

## Current module surface

Core reactivity and lifecycle:

- `Solid.Setup` (the monad for owned code: component bodies, roots, list mappers)
- `Solid.Signal` (`Accessor` is a `Monad`; signals, `get`, `set`, `modify`)
- `Solid.Reactivity` (memos, split effects, reactions, `flush`)
- `Solid.Root`, `Solid.Owner`, `Solid.Lifecycle` (`onCleanup`, `onSettled`)
- `Solid.Async` (`createAsync` over `Aff`, `isPending`, `latest`, `refresh`, `resolve`)
- `Solid.Action` (transactional async mutations, optimistic values)
- `Solid.Store` (typed paths, pure updates, projections, `createSelector`)
- `Solid.Utility` (`mapArray` keyed / unkeyed / by key, `repeat`)
- `Solid.Context`
- `Solid.Web`, `Solid.Web.SSR`

Routing, head tags and start mode:

- `Solid.Router` (`@solidjs/router` 2: `route @"/users/:id"` with params parsed from the path at compile time, `layout`, `createRouter`, `routerView`, `useLocation`, `useNavigate`, `navigateTo`, `useMatch`)
- `Solid.Router.Path` (`href @"/users/:id/:tab?" { id, tab }`: URLs built from exactly the params a path declares)
- `Solid.Meta` (`@solidjs/meta` 1.0: `title`, `meta`, `link`, `stylesheet`, `style`, `script`, `base`, `head`, `key`; typed like elements, no provider)
- `Solid.Start.ServerFunction` (`call :: ServerFunction a b -> a -> Aff b` for `"use server"` functions, with `Serializable` arguments and results)
- `Solid.Start.RequestEvent` (the current request, cookies, typed `locals`), `Solid.Start.Response` (`httpStatus`, `httpHeader`), `Solid.Start.Middleware`

UI authoring:

- `Solid.JSX` (lazy view descriptions: `text`, `reactive`, `fragment`, `empty`)
- `Solid.Component` (`component`, `element`, `children`, `createUniqueId`, `lazy`)
- `Solid.DOM` (any tag or attribute, `classWhen`, `innerHTML`, `ref`, `on`)
- `Solid.DOM.HTML` / `Solid.DOM.Props` (typed HTML elements and properties, generated from `dom-indexed` by `npm run gen:dom`)
- `Solid.DOM.SVG` / `Solid.DOM.SVG.Props` (SVG elements and presentation attributes)
- `Solid.DOM.EventAdapters` (optional adapters built on `web-events`, `web-uievents`, `web-html`, `web-dom`, `web-file`)
- `Solid.Control` (`when`, `showMaybe`, `forEach` (keyed / unkeyed / by key), `repeat`, `switch`, `loading`, `errored`, `reveal`, `portal`, `dynamic`, hydration controls)

## Design stance

- Bindings over Solid's public API (`solid-js`, `@solidjs/web`, `@solidjs/router`, `@solidjs/meta`, `@solidjs/vite-plugin` start mode), not a reimplementation of Solid. The value added is types that reject incorrect code.
- Solid-native naming only. No React-style `use*` API layer.
- Pre-1.0 project. API can change directly when a better design is found.
- Public wrappers prefer typed errors over throw-based behavior.

For rationale, decisions and findings, see `docs/solid-2-migration.md`.

## Start mode (full-stack apps)

Solid 2 retires SolidStart; its serving layer is start mode in `@solidjs/vite-plugin`. A PureScript app plugs in as the start-mode `app` module (a `Solid.Component.Component`), see `src/Examples/StartMode/Host` and `src/Examples/HackerNews/Host`:

```js
// vite.config.mjs
solid({
  start: { app: "./app.js", node: true },
  ssr: true,
  // Compiled FFI lives in output/<Module>/foreign.js, outside the plugin's
  // default src/** filter. Without this, "use server" functions are not
  // transformed and ship to the browser.
  serverFunctions: { filter: { include: ["output/**/foreign.js"] } },
})
```

Server functions are ordinary `"use server"` functions in FFI files, declared as `foreign import save :: ServerFunction NewTodo Todo` and called with `Solid.Start.ServerFunction.call`. Arguments and results must be `Serializable` (primitives, `Nullable`, arrays, records): PureScript ADTs don't survive serialization, and using one is a compile error. On the client, `call` refuses to run a function the plugin didn't transform.

## Quick start

Prerequisites:

- Node.js 22.12+ and npm
- PureScript 0.15 and Spago (`spago` on PATH)

Install dependencies:

```bash
npm install
```

Run tests:

```bash
npm test
```

```bash
npm run test:all
```

## Example apps

- `src/Examples/Counter.purs`: signals, memos, typed elements and events.
- `src/Examples/TodoMVC.purs`: TodoMVC on the fine-grained store (toggling a todo updates one row).
- `src/Examples/Hydration`: an app rendered on the server and hydrated in the browser.
- `src/Examples/StartMode`: the smallest start-mode app, with a server function.
- `src/Examples/HackerNews`: typed routes, server functions and streamed SSR against the Hacker News API.

```bash
npm run build:example:hackernews
```

```bash
PORT=3000 npm run start:example:hackernews
```

## Minimal example

Derived values are pure `Accessor` computations, owned code runs in `Setup`,
and writes happen in `Effect`:

```purescript
module Example.Core where

import Prelude

import Data.Tuple (Tuple(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Solid.Reactivity (createEffect_, createMemo)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, modify_)

example :: Effect Unit
example = do
  setCount <- createRoot \_ -> do
    count /\ setCount <- createSignal 1
    doubled <- createMemo ((_ * 2) <$> count)
    -- compute (tracked, pure) / apply (untracked, effects allowed)
    createEffect_ (Tuple <$> count <*> doubled) \(n /\ d) ->
      log ("count=" <> show n <> ", doubled=" <> show d)
    pure setCount

  -- Writes are Effects: not allowed inside the root body above.
  modify_ setCount (_ + 1)
```

## Getting started UI example

Elements are typed by the attributes and events each one supports
(`Solid.DOM.HTML`, `Solid.DOM.Props`), and every property or text accepts
either a plain value or an `Accessor`:

```purescript
module Example.UI where

import Prelude

import Data.Either (Either(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Solid.Component as Component
import Solid.DOM (classWhen)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (text)
import Solid.Signal (createSignal, modify_)
import Solid.Web (render, requireBody)

clicker :: Component.Component {}
clicker = Component.component \_ -> do
  clicks /\ setClicks <- createSignal 0
  pure $ H.div [ P.class_ "app" ]
    [ H.button
        [ P.onClick \_ -> modify_ setClicks (_ + 1)
        , classWhen "busy" ((_ > 3) <$> clicks)
        ]
        [ text "Click" ]
    , H.span_ [ text (show <$> clicks) ]
    ]

main :: Effect Unit
main = requireBody >>= case _ of
  Left webError -> log (show webError)
  Right body -> void (render (Component.element clicker {}) body)
```

`P.href 1` or `P.onClick` on an element without click events are type
errors, and so is `P.type_ InputCheckbox` on a `<button>`.

## Testing strategy in this repo

- `npm test`: client specs (`Test.Main`, rendered against happy-dom, Solid's dev build) and server specs (`Test.Server.Main`, Solid's server dev build). Specs fail on any Solid dev diagnostic.
- `npm run test:purescript:es`: the same suites compiled with `purs-backend-es`.
- `npm run test:browser-smoke`: Counter and TodoMVC production bundles in Chromium.
- `npm run test:hydration`: server render in Node, hydrate in Chromium, DOM reuse and interactivity.
- `npm run test:start`: the start-mode example built with Vite, SSR, hydration and a server function call.
- `npm run bench`: the rows benchmark (see `docs/benchmarks`).
- `npm run test:all`: everything but the bench.

## Repo guide

- `src/Solid/*`: PureScript modules and their FFI.
- `src/Examples/*`: example apps.
- `scripts/gen-dom.mjs`: generates `Solid.DOM.HTML` / `Solid.DOM.Props` / SVG from `dom-indexed`.
- `test/`: specs, browser smoke, hydration, start mode and benchmark harnesses.
- `docs/solid-2-migration.md`: the Solid 2 migration plan, decisions and findings.

## Project status

Active development, pre-1.0.

If you are evaluating the repo, treat this as a Solid-native PureScript runtime/UI foundation with strong typed boundaries, rather than a finalized stable framework.
