# Solid 2.0 migration plan

Status: in progress on branch `solid-2`. Planned 2026-09-30.

## Decisions

| Topic | Decision |
|---|---|
| Target | Solid 2.0 RC, pinned exactly (`solid-js` / `@solidjs/web` `2.0.0-rc.11` at planning time). Re-sync pins as RCs land. |
| Compatibility | Clean break. No 1.x shims (pre-1.0 project). |
| Start layer | Rebuild `Solid.Start.*` as thin typed bindings over `@solidjs/vite-plugin` start mode + `@solidjs/web` server APIs. SolidStart is retired for Solid 2. |
| DOM props | Halogen-style typed prop arrays (continue `Solid.DOM.Typed`). Each setter accepts a static value or an `Accessor`. |

## Solid 2.0 status (at planning time)

- Core: `solid-js@2.0.0-rc.11` (`next` tag). The API is declared frozen at RC, but rc.10 still moved `storePath` out of `solid-js`. There is no stable date yet; `latest` is still 1.9.x.
- Package moves: `solid-js/web` → `@solidjs/web`, `solid-js/store` → `solid-js`, `solid-js/h` → `@solidjs/h`. `@solidjs/web`'s `latest` tag points at rc.0, so always pin exact versions.
- `@solidjs/router` `2.0.0-next.*`: a full redesign (config-based `createRouter` / `defineRoute`, plain `<a>` links, no `<Route>` / `<A>`).
- `@solidjs/meta` `1.0.0-next.*`: no `MetaProvider`; a thin layer over core `useHead`.
- SolidStart: retired for Solid 2. Start mode in `@solidjs/vite-plugin` (`solid({ start: true })`) replaces it. SolidStart 2.0.x runs on Solid 1.x only.
- Primary references: `solidjs/solid@next:documentation/solid-2.0/MIGRATION.md`, RFCs 01–12 in the same folder, https://v2.solidjs.com, and the RC blog post (solidjs.com/blog/solid-2-0-rc-the-big-reveal).

## Design rules

Solid 2's principles, expressed so that the PureScript type checker enforces them.

1. **Derived values are pure; writes are effects.** Solid 2 throws on writes in owned scopes (`REACTIVE_WRITE_IN_OWNED_SCOPE`) and splits effects into a tracked compute phase and an apply phase.
   - `Accessor` is a lawful `Monad` with no `MonadEffect` instance. Derivations are pure values built with `map`, `<*>`, `ado` and `do`.
   - `createEffect :: Accessor a -> (a -> Effect (Effect Unit)) -> Effect Unit`: compute is an `Accessor`, apply is `Effect` and returns a cleanup.
   - `get :: Accessor a -> Effect a` stays as the explicit "read now" at boundaries such as event handlers.

2. **Async is part of the graph.** `createResource` and transitions are gone; async memos replace them.
   - `createAsync :: Accessor (Aff a) -> Effect (Accessor a)`. Dependencies are read in the `Accessor` layer, which matches the 2.0 rule "only reads before the first await are tracked". Superseded fibers are killed.
   - Wrap `isPending`, `latest`, `refresh`, `resolve`, `action`, `createOptimistic` and `createOptimisticStore`.

3. **Passing a prop isn't reading it.** Component props are plain PureScript records, and reactive fields are typed `Accessor a`. `mergeProps` / `splitProps` leave the public API. For JS components only, a RowList class converts `Accessor` fields into getters.

4. **JSX is a description, not an action.** `JSX` is a lazy tagged thunk, realized untracked by its parent or by a control-flow component. Today `DOM.div …` builds DOM as soon as it is evaluated, so `whenElse` renders both branches.

5. **Update exactly what changed.**
   - Elements come from `dynamic(() => tag, { static: true })` in `@solidjs/web`, cached per tag. That one public API covers client render, SSR (`ssrElement`) and hydration (`getNextElement`), with no memo per element.
   - Reactive props become getters on the props object that `spread` consumes.

6. **Fine-grained stores without mutation in user code.** 2.0 store setters are draft-only.
   - Updates use typed paths (`key @"items" >>> index i >>> key @"done"`) plus a pure update description, interpreted on the draft in the FFI.
   - `focus` returns sub-stores. `forEach` over `Store (Array a)` gives each row a `Store a`.

7. **Standards-aligned, typed DOM.** 2.0 sets attributes by default; `classList`, `use:`, `attr:`, `bool:` and `on:` are removed; `class` takes a string, object or array; refs are callbacks or directive factories.
   - Typed prop arrays indexed by the element's allowed attributes.

### FFI rules

- Never import compiled PureScript output (`../Data.Maybe/index.js` and similar) from FFI. It depends on the default backend's data layout and breaks under `purs-backend-es`. Construct `Maybe` / `Either` on the PureScript side, and pass `Nullable` or continuation functions across the boundary.
- Use `EffectFn` / `Fn` uncurried FFI on hot paths.
- Guard every place Solid overloads on `typeof x === "function"`: signal initial values, setter arguments, store values and children. PureScript functions are JS functions.
- 2.0 stores proxy user class instances, and PureScript ADT values are class instances. We need an atomic-leaf policy (see the stores-proxying spike).
- Errors are `Effect.Exception.Error`, not `String`.

## Module map

| Module | 2.0 action |
|---|---|
| Signal / Reactivity | Add `Monad Accessor`, writable derived signals (`createSignal(fn)`), the `ownedWrite` option and `flush`. Split `createEffect` / `createRenderEffect`. `createMemo` loses its init argument and gains `lazy`. Remove `createComputed` and `createDeferred`. `createSelector` → projection. |
| Resource | Delete. Replaced by `Solid.Async`. |
| Lifecycle | `onSettled` (can return a cleanup) and `onCleanup`. |
| Utility / Root | Keep `flush`, `untrack`, the owner functions (a nested `createRoot` is now owned; detach with `runWithOwner(null)`), `mapArray` with keyed modes, and `repeat`. Remove `batch`, `catchError`, `from`, `observable`, `on`, transitions and `indexArray`. |
| Store | Rewrite: typed paths, `reconcile(key)`, `snapshot`, `deep`, `createProjection`, function stores and optimistic stores. Remove `Mutable`. |
| Context | The context object is the provider component. `createContext` requires a default, so `useContext` is total. Delete `withContext`, which mutates `owner.context`. |
| Control | `show` / `showMaybe` / `switch` / `match`; `for` with keyed, unkeyed and by-key modes (`Index` is removed); `repeat`; `loading` (was Suspense); `errored` (receives an `Accessor Error` and a reset); `reveal` (was SuspenseList); `portal` (mount option only); `dynamic`. |
| JSX / DOM / Component | Lazy JSX, per-tag static elements, typed props, and components that take plain records. Generate the HTML and SVG modules instead of hand-writing them. |
| Web / SSR | Import from `@solidjs/web` and drop the deep `dist/server.js` import. `render` / `hydrate` take a `Web.DOM.Element`. `renderToStream` returns an `Aff String` plus stream consumers. Remove `renderToStringAsync` and `getAssets`. |
| Meta | Meta 1.0: no provider, `Accessor` props, core `useHead`. |
| Router | Router 2: `createRouter` / `defineRoute` config, plain `<a>` links, typed params from the existing Pattern / Params modules. |
| Start.* | Start mode plus `@solidjs/web` server APIs: request event, middleware, `httpStatus` / `httpHeader`, `redirect` / `respond`, cookies and server functions. |

## Phases

### Phase 0 — Groundwork (1.x, no behaviour change)
- [x] Branch `solid-2`.
- [x] FFI hygiene: library FFI no longer imports compiled output. `Maybe` / `Either` / `Tuple` cross the boundary as `Nullable`, as `Just` / `Nothing` passed in from PureScript, or as `{ name, value }` records. Errors are thrown in JS and caught in PureScript (`Solid.Internal.Error.tryMessage`).
  - The whole suite passes on both backends (`npm test`, `npm run test:purescript:es`).
  - Deferred to the Phase 1/3 rewrites: `Error`-typed public errors, and uncurried FFI on the signal and element hot paths.
  - Deferred to Phase 6: the example FFI files (`src/Examples/**/Api.js`) and the browser smoke harness, which still import `output/`.
- [x] Test runner: `spec` + `spec-node`. `npm run test:client` (browser conditions) runs `Test.Main`; `npm run test:server` (default Node conditions) runs `Test.Server.Main` (SSR + Start). Async suites are real `Aff` tests; before, `launchAff_` let their failures escape.
  - Add the `development` condition in Phase 1, once Solid 2's coded diagnostics exist.
- [x] Benchmark harness: `npm run bench -- <label>` (`src/Bench/Rows.purs`, `test/bench/run-bench.mjs`). Baseline: `docs/benchmarks/baseline-1.x.json`.
  - "Select row" is not measured yet, because 1.x has no working reactive attributes (see findings).
- [x] Spikes against rc.11 (see findings).

## Phase 0 findings

1. **Reactive attributes don't work on 1.x.** An `Accessor` passed as an attribute (`value: draft`, `className: activeClass`) is assigned as a raw function. The benchmark probe reads `"function () { [native code] }"`. TodoMVC's input value, toggle-all `checked` and filter classes are affected. Phase 3's typed props fix this by construction.
2. **Aff cancellation works (spike 1).** `onCleanup` inside an async memo compute is allowed, runs when a newer computation supersedes it and on owner disposal, and produces no dev warnings. Superseded results never reach effects. So `createAsync :: Accessor (Aff a) -> Effect (Accessor a)` can kill stale fibers. Note: the previous cleanup runs just *after* the new compute starts.
3. **Stores break PureScript ADTs (spike 2).** Solid 2 proxies user class instances.
   - Default backend: a `Just` read back from a store is **not** `instanceof Just`, and `Nothing` loses its singleton identity, so pattern matching silently takes the wrong branch.
   - purs-backend-es ADTs are plain `{ tag, _1 }` objects, indistinguishable from records at runtime.
   - Frozen values pass through untouched (same identity).
   - The store never mutates the initial value (draft writes go to its own copy).
   - **Phase 2 design:** a `StoreValue` type class (instance chain: records → wrapped per field, arrays → wrapped per element, anything else → atomic, frozen on write), so the policy follows the type, not a runtime guess.

## Baseline (1.x, `docs/benchmarks/baseline-1.x.json`)

Medians on this machine, headless Chromium, click to next frame. Operations under 10 ms vary by about 1–2 ms between runs.

| Operation | 1.x median |
|---|---|
| create 1k rows | 20.4 ms |
| replace 1k rows | 25.9 ms |
| update every 10th row | 9.2 ms |
| swap rows | 9.3 ms |
| append 1k rows | 24.4 ms |
| clear 1k rows | 3.0 ms |
| create 10k rows | 230.3 ms |
| bundle (min / gzip / brotli) | 35.6 kB / 12.5 kB / 11.3 kB |

### Phase 1 — Reactive core on 2.0
Pin `solid-js` and `@solidjs/web` exactly. Port Signal, Accessor, Memo, Effect, Owner, Lifecycle, `flush` / `untrack` and `Solid.Async`.
Exit: core tests pass under dev conditions with zero Solid diagnostics.

### Phase 2 — Stores
Typed paths, draft interpretation, reconcile, snapshot / deep, projections, function stores, optimistic stores and the atomic-leaf policy.

### Phase 3 — View layer
JSX thunks, static elements, typed props, components, control flow, context, portal, dynamic, refs and directives. Generate the HTML and SVG modules.
Exit: UI tests and browser smoke pass, and the benchmark is compared with the baseline.

### Phase 4 — SSR and hydration
`renderToString`, `renderToStream`, `HydrationScript`, `NoHydration` / `Hydration`, and the `ssrSource` / `deferStream` options. Add an SSR → hydrate smoke test.

### Phase 5 — Ecosystem (last; still prerelease)
Meta 1.0 → Router 2 → start mode (after the server-functions spike).

### Phase 6 — Examples and docs
Port Counter, TodoMVC and Hacker News. Write a migration guide for purs-solid users and a benchmark report.

## Risks and spikes

1. ~~Aff cancellation~~: resolved in Phase 0 (works).
2. ~~Stores proxying PureScript ADTs~~: resolved in Phase 0 (`StoreValue` class, freeze non-structural values).
3. `"use server"` over compiled PureScript output: does `@solidjs/vite-plugin` transform `output/**`? This decides the Start design.
4. Prerelease churn in router, meta and vite-plugin: pin exact versions and re-sync each phase.
