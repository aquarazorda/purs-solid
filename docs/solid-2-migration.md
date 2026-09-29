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

**Scope: bindings, not a reimplementation.** purs-solid calls Solid's public API (`solid-js`, `@solidjs/web`, and later `@solidjs/router` / `@solidjs/meta`). It never reimplements or reaches into Solid internals. The JS side exists only where a PureScript type can't express a JS idiom directly, for example:
- turning lazy `JSX` into what `insert` accepts;
- boxing `Just false` for `Show`;
- freezing ADTs before they enter a store;
- driving `action`'s generator protocol.

Because PureScript can't use Solid's JSX compiler, elements go through the public `dynamic(() => tag, { static: true })`, and Solid does client rendering, hydration and SSR itself. We don't hand-write compiled output against compiler-target helpers (`getNextElement`, `ssrElement`, `assign`, `sharedConfig`). An experiment doing that was 15–25% faster at bulk creation, but it would make Solid's hydration and SSR internals ours to maintain.

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

7. **Owned code has its own monad.** Solid 2 rejects signal writes, `refresh` and actions in owned scopes (component bodies, memos, root bodies), and warns on untracked reads at the top of a component. All of these are runtime checks, in dev builds only.
   - Owned code runs in `Setup`, a zero-cost newtype over `Effect` with no `MonadEffect` instance. `set` / `modify` / `refresh` / `get` exist only in `Effect`, so these mistakes don't compile.
   - `createMemo`, `createEffect`, `onCleanup` and `onSettled` exist only in `Setup`, so computations can't be created where nothing disposes them. `Effect` code enters `Setup` only via `createRoot` or `runWithOwner owner`.
   - `getOwner :: Setup Owner` is total. `sample :: Accessor a -> Setup a` is the explicit untracked read.
   - The single escape hatch is `liftSetup` (for example `Ref.new`). Solid's dev build still reports a write smuggled through it.
   - `createSignal` / `createRoot` work in both monads (`MonadReactive`; the class is sealed, so its member is not exported).

8. **Standards-aligned, typed DOM.** 2.0 sets attributes by default; `classList`, `use:`, `attr:`, `bool:` and `on:` are removed; `class` takes a string, object or array; refs are callbacks or directive factories.
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

### Phase 1 — Reactive core on 2.0 ✅
- [x] Pinned `solid-js`, `@solidjs/web` and `@solidjs/h` `2.0.0-rc.11`, `@solidjs/router` `2.0.0-next.31` and `@solidjs/meta` `1.0.0-next.2` (router and meta are only there to satisfy peer dependencies until Phase 5).
- [x] `Solid.Setup`: owned-scope monad (design rule 7).
- [x] `Solid.Signal`
  - `Accessor` is a `Monad`, plus `Semigroup`, `Monoid`, `HeytingAlgebra` and `BooleanAlgebra` instances.
  - Function values (including `Effect`) are boxed transparently.
  - `modify` returns the value it wrote; `modify_` discards it.
  - New `eqEquality`, `sample`, and a pure `untrack`.
- [x] `Solid.Reactivity`
  - `createMemo(With)`, with no initial value and a `lazy` option.
  - `createWritableMemo` (Solid 2's function form of `createSignal`).
  - Split `createEffect` / `createEffect_` / `createEffectWith` (`defer`, `onError`), and `createRenderEffect(_)`.
  - `createReaction` / `track`, `flush` / `withFlush`.
  - Removed: `createComputed`, `createDeferred`, `createSelector` (→ projections, Phase 2).
- [x] `Solid.Lifecycle`: `onCleanup`, `onSettled(_)` (the callback returns its cleanup; `onCleanup` can't be called inside it, by type).
- [x] `Solid.Root` (a nested root is owned by its parent) and `Solid.Owner` (`getOwner`, `runWithOwner`).
- [x] `Solid.Context`: required default, total `useContext`, `provide`. Removed the `withContext` owner-mutation hack.
- [x] `Solid.Async`
  - `createAsync :: Accessor (Aff a) -> Setup (Accessor a /\ Refresh a)`: superseded fibers are killed, and only `createAsync` yields a `Refresh`.
  - `refresh`, `refreshAff`, `isPending`, `latest`, `resolve`.
  - `Solid.Resource` is deleted.
  - Deferred: `action`, `createOptimistic`, `createOptimisticStore` (they go with stores in Phase 2).
- [x] `Solid.Utility`: `mapArray`, `mapArrayUnkeyed`, `mapArrayBy`, `repeat`. Removed `batch`, `catchError`, `from`, `observable`, `on`, transitions, `indexArray`, `mergeProps` and `splitProps`.
- [x] `Solid.Component`: bodies are `Setup`; `lazy` takes an `Aff`.
- [x] `Solid.Web.SSR` (pulled forward from Phase 4): imports `@solidjs/web` under Node's default conditions. `renderToStringAsync` now awaits `renderToStream`. `getAssets` is replaced by `renderToStringWithHead` (Solid 2's `onHead`).
- [x] Tests
  - Client specs run with `--conditions=development`. `Test.Solid.solidIt` fails a test on any Solid warning or error diagnostic (via `OBSERVE.diagnostics`).
  - 45 client and 13 server specs pass on both backends, plus the Start server smoke test.

**Transitional state until the later phases:**
- `Solid.Control`, `Solid.DOM` and `Solid.JSX` load on 2.0 (Control maps onto `Loading`, `Errored`, `Reveal` and unkeyed `For`), but their API is unchanged until Phase 3.
- `Solid.Store`, `Solid.Meta` and `Solid.Router` only load (namespace imports); their suites are pending.
- The browser smoke harness (`test/browser`) still targets 1.x and is rewritten in Phase 3.
- Bench on the transitional view layer (`docs/benchmarks/phase1-transitional.json`): create 1k rows 25.7 ms (1.x: 20.4), 10k rows 258 ms (1.x: 230), gzip bundle 29.6 kB (1.x: 12.5 kB). Most of the bundle growth is Solid 2's runtime.

### Phase 2 — Stores and actions ✅
- [x] `Solid.Store`, rewritten for draft-only setters.
  - **Reads:** `Store s` is a read-only cursor.
    - `focus (key @"a" >>> key @"b")` narrows it; `Path` is total (record labels only) and is a `Category`.
    - `value :: Store a -> Accessor a` tracks exactly the focused part and returns an immutable value (`deep` snapshot for structure).
    - `items :: Store (Array a) -> Accessor (Array (Store a))` gives a stable cursor per element for keyed rows. It requires record or array elements (`StoreObject`).
    - `snapshot` is the untracked read in `Effect`.
  - **Writes:** `update :: StoreSetter s -> Update s -> Effect Unit`, with a pure, monoidal `Update` description applied to the draft in the FFI.
    - Combinators: `at path`, `set`, `modify`, `push`, `filter`, `atIndex` (no-op out of range), `each`, `eachWhere`, `reconcile`, `reconcileBy`.
    - Writes exist only in `Effect`.
  - **Value policy:** `StoreValue`, a sealed instance chain.
    - Records and arrays are structural (tracked per field / element).
    - Primitives are free (no preparation walk).
    - Every other type is atomic and frozen before it enters the store, so Solid never proxies it and pattern matching on ADTs read back from a store works on both backends (spike 2).
    - `createStore` requires a record or array root, and gives a custom type error otherwise.
  - **Derived:** `createProjection :: Accessor (Update s) -> s -> Setup (Store s)` (the compute is pure: it *returns* the update). `createSelector` replaces 1.x `createSelector` and notifies only the rows whose selection changed.
  - **Removed:** the string-array path setters, `produce`, `createMutable` and `modifyMutable`.
- [x] `Solid.Action` (deferred from Phase 1).
  - `Action` is a free monad with `MonadEffect` / `MonadAff`. Every `liftAff` is a transaction-safe suspension point (the FFI drives Solid's generator protocol), so the JS "`await` without `yield`" mistake can't be written.
  - `action :: (a -> Action r) -> a -> Aff r`.
  - Optimistic values: `createOptimistic` (reverts to its initial value) and `createOptimisticFrom` (follows a source).
  - Optimistic stores: `createOptimisticStore` and `createOptimisticProjection`.
  - Optimistic writes (`setOptimistic`, `modifyOptimistic`, `updateOptimistic`) exist **only** as `Action` steps: outside an action there would be nothing to revert them.
- [x] Tests: `Test.Core.Store` (11 specs) and `Test.Core.Action` (5 specs). They cover fine-grained notification, ADT round-trips, row identity through `mapArray` and `reconcileBy`, immutability, projections, the selector, and transactional isolation of real writes during an action. 61 client and 13 server specs pass on both backends.

**Finding:** Solid 2 keeps an element's proxy (and so its row) across a `reconcile` only while something reads that element's fields. Rendered rows always do; a test has to observe the fields too.

### Phase 3 — View layer ✅
- [x] **`JSX` is a lazy description** (`Solid.Internal.View`, one FFI file, because everything needs `realize`).
  - Building JSX does nothing; rendering creates fresh DOM, so a value can be reused.
  - Control-flow content goes through getters, so hidden branches are never created (on 1.x `whenElse` built both).
  - `text` and every prop accept a plain value or an `Accessor` (`ToBinding` instance chain).
  - `JSX.reactive :: Accessor JSX -> JSX` is the explicit reactive region.
- [x] **Elements via Solid's public `dynamic(() => tag, { static: true })`** (cached per tag; no memo per element).
  - Solid creates or claims the element and applies props with `spread`, on the client and the server. Reactive props are getters, and children are a getter, so they're created after their parent (hydration order).
  - `xmlns` is passed only for SVG tags that also exist in HTML.
  - Several `class` props merge into one class value.
  - A first version hand-wrote the compiled-output path against compiler-target helpers. It was dropped to stay on public API (see Scope).
  - Reactive regions outside element children are wrapped in `createMemo(…, { sync: true })`, as compiled Solid does for top-level expressions, so errors reach the enclosing `errored` boundary.
- [x] **Typed props from `dom-indexed`.**
  - `scripts/gen-dom.mjs` (`npm run gen:dom`) generates `Solid.DOM.HTML` (112 elements; void elements take no children) and `Solid.DOM.Props` (192 helpers).
  - Each helper is `forall r v a. ToBinding v a => AttrValue a => v -> Prop (label :: a | r)`: the element's row fixes the value type, so `P.type_` takes `InputType` on `<input>` and `ButtonType` on `<button>`.
  - Event helpers are typed by the row (`onClick :: (MouseEvent -> Effect Unit) -> ...`).
  - Verified compile errors: a number as `href`, `onClick` on `<br>`, `InputCheckbox` on `<button>`, `checked` on `<div>`, a number as `value`.
  - `Solid.DOM.AttrValue` renders primitives, `MediaType` and all `dom-indexed` enums, and is open for user instances.
  - `Solid.DOM.SVG` / `Solid.DOM.SVG.Props`: 76 elements on one SVG row, 54 presentation attributes with their case-sensitive DOM names.
  - `Solid.DOM`: `element`, `attr`, `dataAttr`, `ariaAttr`, `classWhen`, `innerHTML` (documented as not escaped), `ref`, `on`.
  - Removed: `Solid.DOM.Events`, `Solid.DOM.Typed*`, and the untyped record props.
- [x] **`Solid.Control`**
  - `when` / `whenElse` (condition, content, fallback).
  - `showMaybe(Else)` and `showMaybeKeyed(Else)`, where `Just false` / `Just 0` still count as present.
  - `forEach` (keyed), `forEachUnkeyed` (replaces `Index`), `forEachBy`, `repeat`.
  - `switch` over a typed `Case` (`match`, `matchMaybe`).
  - `loading`, `errored` (the fallback gets `Accessor Error` and a `reset :: Effect Unit`).
  - `reveal { order, collapsed }`, `portal` / `portalAt :: Element`, `dynamic`, `noHydration` / `hydration`.
- [x] **Components** take plain records and have `Setup` bodies. `children` returns content that's already rendered, and `lazy :: Aff (Component p)`.
- [x] **Mounting:** `Solid.Web.render` / `hydrate :: JSX -> Element -> ...` (`web-dom` `Element`; `Mountable` removed). `Solid.Web.SSR` takes `JSX`. `Solid.Start.App` wraps a `JSX` value.
- [x] **Examples ported:**
  - Counter.
  - TodoMVC, rewritten on the fine-grained store: each row reads only its own fields.
  - Hacker News (view and app), converted mechanically.
  - The bench, with the new **select row** scenario (`createSelector` + `classWhen`).
- [x] **Tests**
  - Client specs run against a real DOM (happy-dom via `--import=./test/setup-dom.mjs`). `Test.Core.View` has 20 specs covering elements, reactive attributes and text, boolean attributes, DOM properties, delegated events, input events, refs, SVG namespaces, dispose, JSX reuse, lazy branches, falsy `Just`, keyed row identity on reorder, unkeyed lists and `repeat`, `switch`, `errored`, `loading` with `createAsync`, component props and context.
  - 76 client and 13 server specs pass on both backends.
  - Browser smoke (`npm run test:browser-smoke`) now drives production bundles of Counter and TodoMVC in Chromium: 22 checks, and it fails on any page error or console warning.

**Benchmark (`docs/benchmarks/phase3.json`, public `dynamic()` path)**

| Operation | 1.x | Phase 1 (transitional) | Phase 3 | (dropped compiler-style path) |
|---|---|---|---|---|
| create 1k rows | 20.4 ms | 25.7 ms | 21.6 ms | 19.6 ms |
| replace 1k rows | 25.9 ms | 27.3 ms | 23.5 ms | 19.5 ms |
| update every 10th row | 9.2 ms | 7.3 ms | 9.0 ms | 6.9 ms |
| swap rows | 9.3 ms | 4.7 ms | 2.5 ms | 2.4 ms |
| select row | n/a (no reactive attributes) | n/a | 3.0 ms | 4.7 ms |
| append 1k rows | 24.4 ms | 26.3 ms | 23.0 ms | 19.3 ms |
| create 10k rows | 230 ms | 258 ms | 221 ms | 174 ms |
| bundle min / gzip | 35.6 kB / 12.5 kB | 81.3 kB / 29.6 kB | 108.2 kB / 38.1 kB | 100.0 kB / 35.3 kB |

The bundle is dominated by Solid 2's reactive core (`@solidjs/signals`: 57 kB minified); the purs-solid view runtime is about 3 kB. `Effect.Aff` (7 kB) comes in through `Component.lazy` and `Solid.Async`.

**Findings**
- **Not a Solid bug (initially misdiagnosed):** `errored` showed an empty fallback for errors thrown inside `JSX.reactive`. A reactive region returned as a component's result was a bare function, so the *parent's* `insert` evaluated it, outside the boundary. Compiled Solid wraps top-level expressions in `memo`, and the runtime now does the same everywhere except direct element children, where the element's own `insert` is already owned correctly (so rows pay nothing extra). With compiled-shaped code, Solid's `Errored` handles both initial and later failures.
- Merged class values render in prop order.

### Phase 4 — SSR and hydration ✅
- [x] **`Solid.Web.SSR`**
  - `renderToString(With)`, `renderToStringWithHead` (replaces `getAssets` via `onHead`), `renderToStringAsync(With)` (awaits `renderToStream`), `renderToReadableStream :: RenderOptions -> JSX -> Effect (Either SsrError (ReadableStream Uint8Array))`, and `hydrationScript(With nonce)`.
  - `RenderOptions` has `nonce`, `renderId` and `noScripts`.
  - A Solid stream can be consumed only once, so each function picks its consumer; no stream object is handed out.
- [x] **Async data across the server/client boundary (`Solid.Async`)**
  - Solid serializes server-resolved async values into the page. PureScript ADTs don't survive that as-is (default backend: constructors are lost), so `AsyncOptions.ssr` makes the choice explicit:
    - `onClient` (default): no serialization; the server renders the loading fallback.
    - `serialized`: requires the sealed `Serializable` class (primitives, arrays, records). Any other type is a compile error with a message pointing to `withCodec`.
    - `withCodec encode decode`: via argonaut `Json`. The memo holds the encoded value; a second memo decodes it once per change.
  - `deferStream` is exposed.
- [x] **Tests**
  - `Test.Server.SSR` (9 specs): hydration keys, escaping, reactive props rendered once, events and refs omitted, SVG, client-default async, serialized async, a codec round-trip for an ADT, sync fallback, the readable stream, the nonce, and `noScripts`.
  - Server specs now run with the `development` condition, so they also fail on Solid diagnostics.
  - `npm run test:hydration` (`test/hydration/run-hydration.mjs`, `Examples.Hydration.*`) does server render in Node and hydration in Chromium with the production bundle. Its 14 checks: every server element is claimed (none recreated); the serialized async value is not refetched; handlers, reactive attributes and classes, keyed rows plus an appended row, the conditional branch and the SVG namespace all work after hydration; and there are no mismatch warnings.
  - Totals: 77 client and 21 server specs, 22 browser-smoke checks, 14 hydration checks.

### Phase 5 — Meta, Router, start mode ✅
- [x] **`Solid.Meta`** on `@solidjs/meta` 1.0: `title` (may be reactive), `meta`, `link`, `stylesheet`, `style`, `script`, `base`, `head`, `key`.
  - Props are typed with the same `dom-indexed` rows as elements, extended with `key`.
  - There's no provider; tags are collected by the core head registry.
  - `Solid.Internal.View.propsComponentElement` builds a JS component's props from typed `Prop`s.
- [x] **`Solid.Router`** on `@solidjs/router` 2 (`2.0.0-next.31`).
  - `route @"/users/:id/:tab?" \props -> …`: the path is parsed at compile time (`Solid.Router.Path`, `Prim.Symbol.Cons`) into the params row `(id :: String, tab :: Maybe String)`, with the same grammar as the router's own TS types (`:x`, `:x?`, `*x`).
  - `props.params` is an `Accessor` of exactly those fields.
  - `layout` (nested routes via `props.children`), `createRouter` (browser / hash / memory history), `routerView`, `routerViewAt` (server URL).
  - `useLocation` (`pathname`, `search`, `hash`, `queryParam`), `useIsRouting`, `useMatch`, `useNavigate` / `navigate` / `navigateTo @path`, `go`.
  - `href @path params` builds URLs from exactly the declared params. Verified compile errors: a missing param, a wrong type, an extra field, a non-`Maybe` optional.
  - Links are plain anchors; the router intercepts them and marks the active one.
- [x] **Removed reimplementations:** the custom PureScript router (`Routing`, `Manifest`, `Navigation`, `Route.*`, `gen-routes`); the whole custom `Solid.Start.*` server framework (Request/Response ADTs, server router, middleware, sessions, serialization, prerender, static assets, entries, runtime); their tests, scripts and the Vinxi / SolidStart-alpha example hosts.
- [x] **Start-mode bindings** (thin, `@solidjs/web` public API):
  - `Solid.Start.ServerFunction`: `call :: Serializable a => Serializable b => ServerFunction a b -> a -> Aff b`. On the client it rejects an untransformed function (via `isServerFunction`).
  - `Solid.Start.RequestEvent`: `getRequestEvent :: Effect (Maybe RequestEvent)`, the web-fetch `Request`, cookies (`parseCookieHeader` / `serializeCookie`), typed `LocalKey` locals.
  - `Solid.Start.Response`: `httpStatus` / `httpHeader`, in `Setup` because they're scope-tied declarations.
  - `Solid.Start.Middleware`: `Request -> Aff Response -> Aff Response`, shaped for `start.middleware`.
- [x] **`Serializable`** gained `Unit`, `Nullable a`, and a custom error that points to `Nullable` or a codec.
- [x] **Examples:**
  - `StartMode`: minimal, and covered by the end-to-end test.
  - `HackerNews`: rewritten on Router 2, server functions against the HN Firebase API and streamed SSR, with comments sent flat and rebuilt into a tree on the client.
  - Checked live: 30 rows server-rendered with no server calls on hydration, client navigation making one RPC, the story page, back navigation, a 404 via `httpStatus`, and no errors.
- [x] **Tests**
  - `Test.Core.Router` (5 specs), Meta DOM spec, `Test.Server.Meta` (2), `Test.Server.Start` (5).
  - `npm run test:start` builds `Examples.StartMode` with Vite and checks SSR, hydration without refetch, the server function call from the browser, and that the function body isn't in the client bundle (7 checks).
  - Totals: 83 client and 16 server specs, 22 browser, 14 hydration, 7 start-mode checks.

**Findings**
- **Security-relevant:** `@solidjs/vite-plugin`'s server-function transform only includes `src/**` by default, while compiled PureScript lives in `output/`. Without `serverFunctions.filter.include: ["output/**/foreign.js"]`, a `"use server"` function is not transformed: it's bundled into the client and runs in the browser. The docs, the example configs and `call`'s runtime check all cover this.
- In "host owns the document" mode (`renderToStringWithHead`), Solid delivers the title as a script that sets `document.title`, not as a `<title>` tag.
- The router adds `data-active` alongside `aria-current="page"` on active links.
- Router data isn't cached between navigations yet (a back navigation refetches). Binding the router's `query` cache is a follow-up.

### Phase 6 — Examples and docs
Port Counter, TodoMVC and Hacker News. Write a migration guide for purs-solid users and a benchmark report.

## Risks and spikes

1. ~~Aff cancellation~~: resolved in Phase 0 (works).
2. ~~Stores proxying PureScript ADTs~~: resolved in Phase 0 (`StoreValue` class, freeze non-structural values).
3. `"use server"` over compiled PureScript output: does `@solidjs/vite-plugin` transform `output/**`? This decides the Start design.
4. Prerelease churn in router, meta and vite-plugin: pin exact versions and re-sync each phase.
