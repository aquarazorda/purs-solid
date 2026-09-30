# Design

## Scope

purs-solid is bindings, not a reimplementation. It calls the public API of `solid-js`, `@solidjs/web`, `@solidjs/router`, `@solidjs/meta` and `@solidjs/vite-plugin` start mode, and never reaches into Solid internals. JavaScript exists only where a PureScript type can't express a JS idiom directly. The value added is types that reject incorrect code.

Elements go through `dynamic(() => tag, { static: true })`, so Solid itself does client rendering, hydration and SSR. Hand-writing compiled output against compiler-target helpers (`getNextElement`, `ssrElement`, …) would be faster at bulk creation, but it would make Solid's hydration internals ours to maintain.

## Rules

1. **Derived values are pure; writes are effects.** `Accessor` is a lawful `Monad` with no `MonadEffect`. Effects split into a tracked compute (`Accessor a`) and an untracked apply (`a -> Effect …`).
2. **Owned code runs in `Setup`**, a newtype over `Effect` with no `MonadEffect`. `set` / `modify` / `refresh` / `get` exist only in `Effect`; computations and lifecycle hooks exist only in `Setup`. The escape hatch is `liftSetup`. `createSignal` / `createRoot` work in both (`MonadReactive`, sealed).
3. **Async is part of the graph.** `createAsync :: Accessor (Aff a) -> Setup (Accessor a /\ Refresh a)`; superseded fibers are killed. Mutations are `Action`s, and optimistic writes exist only inside them.
4. **Passing a prop isn't reading it.** Props are plain records; reactive fields are `Accessor a`.
5. **JSX is a description.** `JSX` is lazy; parents and control flow realize it, so hidden branches are never built.
6. **Stores are updated with typed paths and pure `Update` values**, applied to Solid's draft in the FFI. Non-structural values are frozen before entering a store (`StoreValue`), because Solid 2 proxies class instances and PureScript ADTs are class instances.
7. **Typed DOM.** Props are arrays indexed by each element's `dom-indexed` row; every prop accepts a value or an `Accessor`.
8. **Data crossing server and client is `Serializable`** (primitives, `Nullable`, arrays, records) or goes through an explicit codec.

## FFI rules

- Never import compiled PureScript output from FFI: it breaks under `purs-backend-es`. Build `Maybe` / `Either` on the PureScript side; pass `Nullable` or continuations.
- Use `EffectFn` / `Fn` on hot paths.
- Guard every place Solid overloads on `typeof x === "function"` (signal values, setter arguments, store values, children): PureScript functions are JS functions.
- Errors are `Effect.Exception.Error`.

## Solid 2 behaviour this relies on

- A store keeps an element's proxy (and so its row) across `reconcile` only while something reads that element's fields.
- `@solidjs/vite-plugin` transforms `"use server"` functions only under `src/**` by default. Compiled FFI lives in `output/**/foreign.js`, which must be added to `serverFunctions.filter.include`, or server functions ship to the client. `call` and `queryServer` refuse to run an untransformed function in the browser.
- With `renderToStringWithHead`, Solid delivers the title as a script that sets `document.title`, not as a `<title>` tag.
- Pin exact versions: several of these packages' `latest` npm tags point at old releases.
