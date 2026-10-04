# purs-solid

PureScript bindings for [Solid 2.0](https://github.com/solidjs/solid): fine-grained reactivity, rendering, SSR and hydration, the router, head tags and start mode.

The bindings use Solid's public API only; what they add is types that reject incorrect code. For example, a signal can't be written during setup, a derived value can't perform effects, a prop only type-checks on elements that have it, and a route's params come from its path. See [docs/design.md](docs/design.md).

## Example

```purescript
module Example where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Component as Component
import Solid.DOM.HTML as H
import Solid.Reactivity (createMemo)
import Solid.Signal (createSignal, modify_)
import Solid.Web (mount)

counter :: Component.Component {}
counter = Component.component \_ -> do
  count /\ setCount <- createSignal 0
  doubled <- createMemo ((_ * 2) <$> count)
  pure $ H.div { class: "counter" }
    [ H.button { onClick: \_ -> modify_ setCount (_ + 1), class: { big: (_ > 3) <$> count } } "+"
    , H.span {} (show <$> doubled)
    ]

main :: Effect Unit
main = mount (Component.element counter {})
```

## Modules

- **Reactivity:**
  - `Solid.Signal`, `Solid.Reactivity`;
  - `Solid.Setup` (the monad for component bodies and roots);
  - `Solid.Root`, `Solid.Owner`, `Solid.Lifecycle`, `Solid.Context`, `Solid.Utility`.
- **Async:**
  - `Solid.Async` (`createAsync` over `Aff`; the result is `Async`, which can't be read before it loads);
  - `Solid.Action` (transactional mutations and optimistic values).
- **Stores:** `Solid.Store` (typed paths, pure updates, projections, `createSelector`).
- **Views:**
  - `Solid.JSX`, `Solid.Component`;
  - `Solid.Component.JS` (use JavaScript Solid components);
  - `Solid.Control` (conditionals, `caseOn` for data types, lists, `loading`, `errored`, portals);
  - `Solid.DOM` (props records: `ref`, `class` toggles, `style`, `bindValue`, `data-*` / `aria-*`, `on:` events), `Solid.DOM.HTML`, `Solid.DOM.SVG`. The HTML and SVG modules are generated from `dom-indexed` by `npm run gen:dom`.
- **Rendering:** `Solid.Web` (`mount`, render, hydrate), `Solid.Web.SSR` (string, async and streamed server rendering), `Solid.Errors` (client and server error hooks, safe errors).
- **Routing and head tags:**
  - `Solid.Router` (`route @"/users/:id"` gives the component `{ id :: String }`, `:id<int>` an `Int`);
  - `Solid.Router.Path` (`href`);
  - `Solid.Router.Search` (query params typed by a schema row);
  - `Solid.Router.Query` (cached route data);
  - `Solid.Router.Action` (mutations the router tracks: forms, submissions, revalidation);
  - `Solid.Meta`.
- **Testing:** `Solid.Testing` (mount into a DOM, settle, query, click, type, collect Solid's diagnostics).
- **Start mode:** `Solid.Start.ServerFunction`, `Solid.Start.UseServer`, `Solid.Start.RequestEvent`, `Solid.Start.Response` (status, headers, and the `Reply` of an action: redirect, reload, respond), `Solid.Start.Middleware`.

## Installing

Solid 2 is a release candidate, so pin exact versions:

```bash
npm install --save-exact solid-js@2.0.0-rc.13 @solidjs/web@2.0.0-rc.13
```

```bash
npm install --save-exact @solidjs/router@2.0.0-next.32 @solidjs/meta@1.0.0-next.2
```

```bash
npm install --save-dev --save-exact @solidjs/vite-plugin@3.0.0-next.47
```

The router and meta packages are needed only for `Solid.Router` and `Solid.Meta`, and the Vite plugin only for start mode. Bundle development builds with the `development` export condition to get Solid's diagnostics.

## Start mode

A start-mode app is a `Component`. Use `purs-solid/vite` in place of `@solidjs/vite-plugin`. It takes the same options, with `start.app` and `start.middleware` given as module names. `app` defaults to the module `App` exporting `app`, and a middleware module exports `middleware`.

```js
import solid from "purs-solid/vite";

export default defineConfig({ plugins: [solid({ start: true, ssr: true })] });
```

Server functions are written in PureScript in a server module, which re-exports `Solid.Start.UseServer`. None of its code reaches the browser. Every value it exports must be a `serverFunction`, and arguments and results must be `Serializable`:

```purescript
module App.Api (module Solid.Start.UseServer, save) where

import Solid.Start.ServerFunction (ServerFunction, serverFunction)
import Solid.Start.UseServer (useServer)

save :: ServerFunction NewTodo Todo
save = serverFunction \todo -> Db.insert todo
```

Call them from anywhere with `call`, `queryServer` or `serverAction`.

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

Requires Node.js 22.12+. PureScript, Spago and purs-tidy are pinned dev dependencies.

```bash
npm install
```

```bash
npm run test:all
```

| Script | What it runs |
|---|---|
| `npm test` | client specs (happy-dom) and server specs on Solid's dev build; any Solid diagnostic fails them |
| `npm run test:purescript:es` | the same specs compiled with `purs-backend-es` |
| `npm run test:browser-smoke` | Counter and TodoMVC in Chromium |
| `npm run test:hydration` | server render in Node, hydration in Chromium |
| `npm run test:start`, `npm run test:dev` | the start-mode example built with Vite, and under Vite dev with edits while it runs |
| `npm run test:vite` | the `purs-solid/vite` plugin's own logic |
| `npm run test:types` | props the type checker must accept or reject |
| `npm run gen:dom` | regenerates `Solid.DOM.HTML`, `Solid.DOM.SVG` and `Solid.Internal.Names` |
| `npm run format`, `npm run format:check` | purs-tidy over the library, tests and examples |
| `npm run bench`, `npm run bench:reference` | the rows benchmark, and the same app in plain Solid |

## Performance

The rows benchmark (keyed, after [js-framework-benchmark](https://github.com/krausest/js-framework-benchmark)): `examples/src/Bench/Rows.purs` against the same app in Solid JSX, `test/bench/reference/rows.jsx`. Medians in headless Chromium, Solid `2.0.0-rc.13`:

| Operation | Solid JSX | purs-solid |
|---|---|---|
| create 1k rows | 12.0 ms | 19.1 ms |
| replace 1k rows | 13.8 ms | 20.3 ms |
| update every 10th row | 2.9 ms | 3.4 ms |
| swap rows | 1.3 ms | 1.5 ms |
| create 10k rows | 125.7 ms | 192.6 ms |
| bundle (gzip) | 24.2 kB | 39.1 kB |

Updates cost about the same. Creating DOM is about 1.5x slower: elements go through Solid's `dynamic()` because PureScript can't use Solid's JSX compiler, which clones templates.
