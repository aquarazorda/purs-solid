# purs-solid

PureScript bindings for [Solid 2.0](https://github.com/solidjs/solid): fine-grained reactivity, rendering, SSR and hydration, the router, head tags and start mode.

The bindings use Solid's public API only; what they add is types that reject incorrect code. For example, a signal can't be written during setup, a derived value can't perform effects, a prop only type-checks on elements that have it, and a route's params come from its path. See [docs/design.md](docs/design.md).

## Example

```purescript
module Example where

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
import Solid.Reactivity (createMemo)
import Solid.Signal (createSignal, modify_)
import Solid.Web (render, requireBody)

counter :: Component.Component {}
counter = Component.component \_ -> do
  count /\ setCount <- createSignal 0
  doubled <- createMemo ((_ * 2) <$> count)
  pure $ H.div [ P.class_ "counter" ]
    [ H.button
        [ P.onClick \_ -> modify_ setCount (_ + 1)
        , classWhen "big" ((_ > 3) <$> count)
        ]
        [ text "+" ]
    , H.span_ [ text (show <$> doubled) ]
    ]

main :: Effect Unit
main = requireBody >>= case _ of
  Left error -> log (show error)
  Right body -> void (render (Component.element counter {}) body)
```

## Modules

- **Reactivity:**
  - `Solid.Signal`, `Solid.Reactivity`;
  - `Solid.Setup` (the monad for component bodies and roots);
  - `Solid.Root`, `Solid.Owner`, `Solid.Lifecycle`, `Solid.Context`, `Solid.Utility`.
- **Async:**
  - `Solid.Async` (`createAsync` over `Aff`);
  - `Solid.Action` (transactional mutations and optimistic values).
- **Stores:** `Solid.Store` (typed paths, pure updates, projections, `createSelector`).
- **Views:**
  - `Solid.JSX`, `Solid.Component`;
  - `Solid.Component.JS` (use JavaScript Solid components);
  - `Solid.Control` (conditionals, lists, `loading`, `errored`, portals);
  - `Solid.DOM`, `Solid.DOM.HTML` / `Solid.DOM.Props`, `Solid.DOM.SVG` / `Solid.DOM.SVG.Props`. The HTML and SVG modules are generated from `dom-indexed` by `npm run gen:dom`.
- **Rendering:** `Solid.Web` (render, hydrate), `Solid.Web.SSR` (string, async and streamed server rendering), `Solid.Errors` (client and server error hooks, safe errors).
- **Routing and head tags:**
  - `Solid.Router` (`route @"/users/:id"` gives the component `{ id :: String }`);
  - `Solid.Router.Path` (`href`);
  - `Solid.Router.Query` (cached route data);
  - `Solid.Router.Action` (mutations the router tracks: forms, submissions, revalidation);
  - `Solid.Meta`.
- **Start mode:** `Solid.Start.ServerFunction`, `Solid.Start.RequestEvent`, `Solid.Start.Response` (status, headers, and the `Reply` of an action: redirect, reload, respond), `Solid.Start.Middleware`.

## Installing

Solid 2 is a release candidate, so pin exact versions:

```bash
npm install --save-exact solid-js@2.0.0-rc.11 @solidjs/web@2.0.0-rc.11
```

```bash
npm install --save-exact @solidjs/router@2.0.0-next.31 @solidjs/meta@1.0.0-next.2
```

```bash
npm install --save-dev --save-exact @solidjs/vite-plugin@3.0.0-next.46
```

The router and meta packages are needed only for `Solid.Router` and `Solid.Meta`, and the Vite plugin only for start mode. Bundle development builds with the `development` export condition to get Solid's diagnostics.

## Start mode

A start-mode app is a `Component` exported from the plugin's `app` module. Server functions are `"use server"` functions in FFI files, declared as `foreign import save :: ServerFunction NewTodo Todo` and called with `call`. Their arguments and results must be `Serializable`.

Compiled FFI lives in `output/`, outside the plugin's default `src/**` filter, so include it explicitly. Otherwise server functions ship to the browser:

```js
solid({
  start: { app: "./app.js", node: true },
  ssr: true,
  serverFunctions: { filter: { include: ["output/**/foreign.js"] } },
})
```

See `examples/src/StartMode/Host` and `examples/src/HackerNews/Host`.

## Examples

The `examples` workspace package holds:

- `Counter`, `TodoMVC`: client-side apps;
- `Hydration`: server rendering and hydration;
- `StartMode`: the smallest full-stack app;
- `HackerNews`: typed routes, cached server queries and streamed SSR;
- `Bench`: the rows benchmark.

```bash
npm run build:example:hackernews
```

```bash
PORT=3000 npm run start:example:hackernews
```

## Development

Requires Node.js 22.12+, PureScript 0.15 and Spago.

```bash
npm install
```

```bash
npm run test:all
```

| Script | What it runs |
|---|---|
| `npm test` | client specs (happy-dom) and server specs, both on Solid's dev build; they fail on any Solid diagnostic |
| `npm run test:purescript:es` | the same specs compiled with `purs-backend-es` |
| `npm run test:browser-smoke` | Counter and TodoMVC in Chromium |
| `npm run test:hydration` | server render in Node, hydration in Chromium |
| `npm run test:start` | the start-mode example built with Vite and driven in Chromium |
| `npm run bench`, `npm run bench:reference` | the rows benchmark, and the same app in plain Solid ([results](docs/benchmarks/README.md)) |
