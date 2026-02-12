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

- `Solid.Signal`
- `Solid.Reactivity`
- `Solid.Root`
- `Solid.Utility` (`batch`, `catchError`, `from`, `mapArray`, `indexArray`, `mergeProps`, `splitProps`, `observable`, `startTransition`, `useTransition`, and related helpers)
- `Solid.Lifecycle`
- `Solid.Resource`
- `Solid.Context`
- `Solid.Store`
- `Solid.Web`
- `Solid.Web.SSR`

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

- `Solid.JSX`
- `Solid.Component` (`component`, `element`, `children`, `createUniqueId`, `lazy`)
- `Solid.DOM` (generic + common HTML tags)
- `Solid.DOM.HTML` (full HTML constructors)
- `Solid.DOM.SVG` (full SVG constructors)
- `Solid.DOM.Events` (thin handler helpers over `Web.Event.Event`)
- `Solid.DOM.EventAdapters` (optional adapters built on `web-events`, `web-uievents`, `web-html`, `web-dom`, `web-file`)
- `Solid.Control` (`Show`/`For`/`Index`/`Switch`/`Match` wrappers, `ErrorBoundary`, `Suspense`, `SuspenseList`, `NoHydration`, `Dynamic`, `Portal`, and related helpers)

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

This example shows the core reactivity wrappers (signals, memo, effect, root):

```purescript
module Example.Core where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Solid.Reactivity (createEffect, createMemo)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, modify)

example :: Effect Unit
example =
  createRoot \dispose -> do
    count /\ setCount <- createSignal 1

    doubled <- createMemo do
      n <- get count
      pure (n * 2)

    _ <- createEffect do
      n <- get count
      d <- get doubled
      log ("count=" <> show n <> ", doubled=" <> show d)

    _ <- modify setCount (_ + 1)
    _ <- modify setCount (_ + 1)

    dispose
```

`Solid.Web` uses `Either` for render/hydrate outcomes, so client-only/runtime failures are explicit in types.

## Getting started UI example

This example mounts a small component into `document.body` using `Solid.Web.requireBody` and `Solid.Web.render`.

```purescript
module Example.UI where

import Prelude

import Data.Either (Either(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Solid.Component as Component
import Solid.DOM as DOM
import Solid.DOM.Events as Events
import Solid.Signal (createSignal, modify)
import Solid.Web (render, requireBody)

main :: Effect Unit
main = do
  clicks /\ setClicks <- createSignal 0

  app <- pure $ Component.component \_ ->
    pure $ DOM.div { className: "app" }
      [ DOM.span_ [ DOM.text "purs-solid mounted" ]
      , DOM.button
          { onClick: Events.handler_ do
              _ <- modify setClicks (_ + 1)
              pure unit
          }
          [ DOM.text "Click" ]
      ]

  mountResult <- requireBody
  case mountResult of
    Left webError ->
      log ("Mount error: " <> show webError)

    Right mountNode -> do
      renderResult <- render (pure (Component.element app {})) mountNode
      case renderResult of
        Left webError ->
          log ("Render error: " <> show webError)
        Right _dispose ->
          pure unit
```

Note: this snippet keeps the disposer in scope as `_dispose`. In a real app you may store and call it to unmount.

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
