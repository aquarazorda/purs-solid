# Design

## Scope

purs-solid is bindings, not a reimplementation. It calls the public API of `solid-js`, `@solidjs/web`, `@solidjs/router`, `@solidjs/meta` and `@solidjs/vite-plugin` start mode, and never reaches into Solid internals. The value added is types that reject incorrect code.

Runtime logic lives in JS FFI that calls Solid; PureScript supplies the types (rows, instance chains, type-level parsing) and thin calls. PureScript values take the shape Solid expects, so the FFI passes them straight through:

- Options are records with optional fields, handed to Solid as they are. Solid applies its own defaults; PureScript never restates them.
- No ADT → string → JS round trips, and no PureScript ADTs or interpreters on hot paths where a JS check does the job.
- Plain DOM access uses registry bindings (`web-html`, `web-dom`, …).

Elements go through `dynamic(() => tag, { static: true })`, so Solid itself does client rendering, hydration and SSR. Hand-writing compiled output against compiler-target helpers (`getNextElement`, `ssrElement`, …) would be faster at bulk creation, but it would make Solid's hydration internals ours to maintain.

## Rules

1. **Derived values are pure; writes are effects.** `Accessor` is a lawful `Monad` with no `MonadEffect`. Effects split into a tracked compute (`Accessor a`) and an untracked apply (`a -> Effect …`).
2. **Owned code runs in `Setup`**, a newtype over `Effect` with no `MonadEffect`. `set` / `modify` / `refresh` / `get` exist only in `Effect`; computations and lifecycle hooks exist only in `Setup`. The escape hatch is `liftSetup`. `createSignal` / `createRoot` work in both (`MonadReactive`, sealed).
3. **Async is part of the graph.** `createAsync :: Accessor (Aff a) -> Setup (Async a /\ Refresh a)`; superseded fibers are killed. An `Async` may not have loaded, so it has no `get` or `sample`: it is rendered, derived from (`Tracked f` accepts `Accessor` and `Async`), or awaited with `resolve`. A `loadingValue` makes the result an `Accessor`. Async projections are `AsyncStore`s, whose values read as `Async`. Mutations are `Action`s, and optimistic writes exist only inside them.
4. **Passing a prop isn't reading it.** Props are plain records; reactive fields are `Accessor a`.
5. **JSX is a description.** `JSX` is lazy; parents and control flow realize it, so hidden branches are never built.
6. **Stores are updated with typed paths and pure `Update` values**, applied to Solid's draft in the FFI. Non-structural values are frozen before entering a store (`StoreValue`), because Solid 2 proxies class instances and PureScript ADTs are class instances.
7. **Typed DOM.** Element props are records checked field by field against the element's `dom-indexed` row; every attribute accepts a value or an `Accessor`.
8. **Data crossing server and client is `Serializable`** (primitives, `Nullable`, arrays, records) or goes through an explicit codec.

## FFI rules

- Never import compiled PureScript output from FFI: it breaks under `purs-backend-es`. Build `Maybe` / `Either` on the PureScript side; pass `Nullable` or continuations.
- Use `EffectFn` / `Fn` on hot paths.
- Guard every place Solid overloads on `typeof x === "function"` (signal values, setter arguments, store values, children): PureScript functions are JS functions.
- Errors are `Effect.Exception.Error`.

## Solid 2 behaviour this relies on

- A store keeps an element's proxy (and so its row) across `reconcile` only while something reads that element's fields.
- `purs` can't emit a `"use server"` directive, so `purs-solid/vite` wraps `@solidjs/vite-plugin`: a compiled module that re-exports `useServer` gets a module-level `"use server"`, and Solid's compiler turns it into references on the client, dropping all of its imports. It keeps only the module's public exports: purs-backend-es exports every top-level binding, so those come from its CoreFn. `call` and `queryServer` refuse to run an untransformed function in the browser.
- Solid's `start.app` and `start.middleware` must be files inside the Vite root with a default export, so the wrapper writes one-line re-exports to `node_modules/.purs-solid/`.
- Server-side `lazy` finds a module's client chunk (to preload it before hydration) through a `$$moduleUrl` export that Solid's JSX transform adds to JSX modules; the wrapper adds it to compiled modules for the server.
- `purs` rewrites a burst of output files per build. In dev the wrapper replaces Vite's per-file updates for compiled output with one reload once the burst settles: the server's modules first, then the browser. Otherwise a page can render on half-updated modules or hydrate against the other version.
- With `renderToStringWithHead`, Solid delivers the title as a script that sets `document.title`, not as a `<title>` tag.
- Pin exact versions: several of these packages' `latest` npm tags point at old releases.

## Not bound

- `merge` / `omit`: props are records.
- `createTrackedEffect` (deprecated, breaks rule 1); `createErrorBoundary` / `createLoadingBoundary` / `createRevealOrder` (the control-flow functions cover them).
- `storePath` (typed paths replace it); `defineRoute(s)` / `Router.paths` (`route @path` and `href` replace them).
- Internal and dev exports (`enableExternalSource`, `flatten`, `getObserver`, `$TRACK`, `DEV` / `OBSERVE`).
- `ssrSource` on sync memos, `"hybrid"`, `mapArray`'s `fallback` / `name` (the `*Else` functions cover fallbacks), serializer `plugins`, asset `manifest`, `enableRichArguments`, `live` / `GET`.
