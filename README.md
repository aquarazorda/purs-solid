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

Routing and navigation:

- `Solid.Router` (`Router`/`Route`/`A` wrappers plus `useLocation` and `useNavigate`, client-side router context)
- `Solid.Router.Navigation` (path normalization and browser route-change helpers)
- `Solid.Router.Route.Pattern`
- `Solid.Router.Route.Params`
- `Solid.Router.Routing`
- `Solid.Router.Routing.Manifest`

Document head:

- `Solid.Meta` (`MetaProvider`, `Title`, `Meta`, `Link`, `Style`, `Base`, `Stylesheet`, and `useHead`)

UI authoring:

- `Solid.JSX` (lazy view descriptions: `text`, `reactive`, `fragment`, `empty`)
- `Solid.Component` (`component`, `element`, `children`, `createUniqueId`, `lazy`)
- `Solid.DOM` (any tag or attribute, `classWhen`, `innerHTML`, `ref`, `on`)
- `Solid.DOM.HTML` / `Solid.DOM.Props` (typed HTML elements and properties, generated from `dom-indexed` by `npm run gen:dom`)
- `Solid.DOM.SVG` / `Solid.DOM.SVG.Props` (SVG elements and presentation attributes)
- `Solid.DOM.EventAdapters` (optional adapters built on `web-events`, `web-uievents`, `web-html`, `web-dom`, `web-file`)
- `Solid.Control` (`when`, `showMaybe`, `forEach` (keyed / unkeyed / by key), `repeat`, `switch`, `loading`, `errored`, `reveal`, `portal`, `dynamic`, hydration controls)

## Design stance

- Solid-native naming only. No React-style `use*` API layer.
- Pre-1.0 project. API can change directly when a better design is found.
- Public wrappers prefer typed errors over throw-based behavior.

For rationale and policy details, see `DECISIONS.md`.

## SolidStart effort

- `SolidStart/README.md` - implementation status and commands.
- `SolidStart/IMPLEMENTATION_PLAN.md` - milestone roadmap for SolidStart functionality.
- `SolidStart/ROUTING_CONVENTIONS.md` - file-based routing conventions for PureScript routes.
- Source of truth for the SolidStart example now lives under `src/Examples/SolidStart/`.
- `npm run gen:example:solid-start-app` generates `examples/solid-start/` (Vite + `@solidjs/start` alpha + Nitro).
- Generated `examples/solid-start/src`, `examples/solid-start/public`, and app config files are gitignored on purpose.
- `npm run test:start` runs route generation and Start smoke checks.

## Quick start

Prerequisites:

- Node.js + npm
- PureScript/Spago toolchain available (`spago` on PATH)

Install dependencies:

```bash
npm install
```

Run tests:

```bash
# PureScript suite
spago test

# Browser smoke suite (build + Playwright smoke)
npm run test:browser-smoke

# Full local check
npm run test:all
```

## Example apps

This repo now has an `examples/` workspace for runnable demo apps.

- `examples/todomvc/` - TodoMVC clone with filtering, toggle-all, and completion controls.
- `examples/counter/` - compact signal/memo example with step presets and event log.
- `examples/solid-start/` - generated SolidStart alpha Hacker News app (generated from `src/Examples/SolidStart/`, not committed as source).
- `src/Examples/SolidStartSSR/` - Vinxi-hosted PureScript SSR app example (runs at `/`).

Build example bundles:

```bash
npm run build:examples
```

Run the SolidStart HackerNews demo:

```bash
npm run install:example:solid-start
npm run dev:example:solid-start
```

Note: the generated SolidStart alpha app currently requires Node.js `>=22`.

Run the Vinxi-hosted SolidStart SSR example:

```bash
npm run install:example:solid-start-ssr
npm run dev:example:solid-start-ssr
```

Serve the repository root and open the examples index:

```bash
npm run serve:examples
# then visit http://localhost:4173/examples/
```

`serve:examples` runs a small Node server for static examples and SSR runtime demo paths.

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

- Unit/integration coverage in `test/Test/*.purs`.
- Browser smoke harness in `test/browser/run-smoke.mjs` + `test/browser/smoke-client.mjs`.
- Smoke tests validate rendering, interactions, control-flow wrappers, and event behavior in a real Chromium runtime.

## Repo guide

- `src/Solid/*` - PureScript modules and FFI wrappers.
- `test/Test/*` - PureScript test suites.
- `test/browser/*` - browser smoke harness.
- `DECISIONS.md` - architecture and API decisions.
- `IMPLEMENTATION_PLAN.md` - milestone tracking and remaining work.

## Project status

Active development, pre-1.0.

If you are evaluating the repo, treat this as a Solid-native PureScript runtime/UI foundation with strong typed boundaries, rather than a finalized stable framework.
