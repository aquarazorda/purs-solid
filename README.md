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
- `Solid.Utility`
- `Solid.Lifecycle`
- `Solid.Resource`
- `Solid.Context`
- `Solid.Store`
- `Solid.Web`

UI authoring:

- `Solid.JSX`
- `Solid.Component`
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
- `npm run test:start` - route generation plus Start server/browser smoke checks.

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
- `examples/solid-start/` - SolidStart implementation scaffold and route fixtures.

Build example bundles:

```bash
npm run build:examples
```

Serve the repository root and open the examples index:

```bash
npm run serve:examples
# then visit http://localhost:4173/examples/
```

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
