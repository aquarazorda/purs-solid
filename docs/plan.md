# Plan: FFI-first bindings, Solid 2 coverage, developer experience

Status: done on `main` (planned and completed 2026-09-30). Source: a review of the code, the compiled output and a CPU profile, plus a comparison of every export in the Solid 2 reference (v2.solidjs.com) against the pinned packages (`solid-js` / `@solidjs/web` rc.11, router next.31, meta next.2, vite-plugin next.46).

## Decisions

| Topic | Decision |
|---|---|
| Scope | Bindings over Solid's public API. No Solid internals or compiler-target helpers, and no reimplementing Solid in PureScript or JS. |
| Where code lives | Runtime logic lives in JS FFI that calls Solid. PureScript supplies the types (rows, instance chains, type-level parsing) and thin calls. |
| Representations | PureScript types match what Solid takes, so the FFI passes values straight through. No PureScript-side defaults, no ADT → string → JS round trips. |
| Options | Records with optional fields (`Row.Union given missing Options`), handed to Solid as is; Solid applies its own defaults. |
| Web APIs | Plain DOM access keeps using registry bindings (`web-html`, `web-dom`, …). |

## Baseline

- `npm test` passes (client and server suites).
- Benchmark (`docs/benchmarks/README.md`): creation is 1.57–1.68x plain Solid, updates 1.20–1.35x, select row ≈. Bundle is 99.6 kB minified vs 66.0 kB.

## Findings

1. **Where creation time goes.** CPU profile of a clear + create 1k rows cycle in Chromium, per cycle:
   - `@solidjs/web` 5.8 ms, `@solidjs/signals` 2.5 ms.
   - purs-solid 1.9 ms, PureScript libraries 0.5 ms.
   - The rest is native DOM and layout.

   The remaining gap is the cost of Solid's `dynamic` + `spread` per element, accepted by design.
2. **Static children cost an effect per element.** `propsObject` always passes `children` as a getter (`src/Solid/Internal/View.js:136`), so `spread` wraps the insert in an effect even when nothing is reactive. Passing a plain value when no child is `Reactive`:
   - median create went from 22.5 to 21.0–21.5 ms, and signals time from 2.5 to 1.9 ms;
   - but children are then realized before the parent's hydration claim, which is unverified.
3. **Store preparers are rebuilt on every update.** `preparer :: Proxy a -> …` is a function (`src/Solid/Internal/Store.purs:26`). The compiled `Store.set` / `push` / `modify` / `reconcile` walk the record fields and allocate closures per call.
4. **`Serializable` is closed.** Confirmed with `purs compile`: `derive newtype instance Serializable UserId` fails with OverlappingInstances, because of the catch-all `Fail` instance (`src/Solid/Internal/Serializable.purs:37`).
5. **Contexts holding `Unit` throw.** `unit` is `undefined`, and Solid's `getContext` treats `undefined` as unset (`ContextNotFoundError`).
6. **Doc comments that contradict Solid:**
   - `render` appends to the mount rather than replacing its content.
   - `renderToStringAsync` / `renderToReadableStream` never reject; render errors go only to `onError`, so `Left` covers only synchronous failures.
   - A bare `refresh` doesn't set `isPending` (needs `affects`).
   - The `lazy` loader pattern (`.then(m => m.x)`) breaks hydration, and there's no `moduleUrl` for SSR preload.
7. **PureScript does runtime work that Solid or the FFI should do:**
   - option defaults that restate Solid's (`defaultNavigateOptions`, `src/Solid/Router.purs:189`);
   - the `Maybe` → `Nullable` → JS clean-up chain for options (`src/Solid/Web/SSR.purs:52`);
   - `Equality` → mode string → `equalityOptions`, which is copied in three FFI files;
   - a `Static`/`Dynamic` `Binding` allocated and matched for every prop (`src/Solid/Internal/View.purs:67-114`);
   - `href` rendering by string splitting and `js-uri` (`src/Solid/Router/Path.purs:87-104`);
   - enums converted in PureScript (`RevealOrder`, `SameSite`, `Namespace`, `AsyncSsr`).
8. **Duplication:**
   - `forImpl` / `forUnkeyedImpl` / `forByImpl`, and `showMaybeImpl` / `showMaybeKeyedImpl`, differ only in `keyed`.
   - `untrackImpl` equals `untrack`.
   - The server-function guard is repeated in `ServerFunction.js` and `Router/Query.js`.
   - `*Else` fallbacks exist for `when` / `showMaybe` / `forEach` only.

## Phases

Every phase ends with `npm test`, `npm run test:purescript:es` and `npm run test:all` green. Phases 1–2 also re-run `npm run bench -- --runs=3` and update `docs/benchmarks`.

### Phase 0 — Rules and doc fixes
- [x] `docs/design.md`: replace "JavaScript exists only where a PureScript type can't express a JS idiom directly" with the decisions above.
- [x] Fix the doc comments from finding 6: `render`, the SSR functions (until Phase 3 adds `onError`), `isPending`.
- [x] Hydration-safe `lazy` (moved here from Phase 3): `lazy "name" load` uses Solid's `{ export }`, plus `preload`.
- [x] `Solid.Context`: box values in the FFI, like signals do, so `Unit` and other `undefined` values work.

### Phase 1 — FFI-first refactor (less PureScript, fewer allocations)
- [x] Options pass through as optional-field records:
  - `createSignalWith`, `createMemoWith`, `createEffectWith`, `createAsyncWith`;
  - the SSR render options, `RouterConfig`, `navigateWith`.

  Delete the `default*Options` records. `onError` stays a PureScript callback, unwrapped in the FFI.
- [x] `Equality` becomes a foreign type holding Solid's `equals` value (`false` or a function). Delete `toEqualityFn` and the three `equalityOptions` copies.
- [x] `ToBinding` becomes a method-less constraint. The FFI dispatches on `typeof v === "function"` (attribute values are never functions). Delete `Binding` and `bindingProp`'s PureScript branch.
- [x] Enums become newtypes over Solid's own values (`RevealOrder`, `SameSite`, `Namespace`); `AsyncSsr` already was one.
- [x] `href`: keep the type-level parsing and move rendering to JS (native `encodeURIComponent`, parsed pattern cached). Drop `js-uri` if nothing else needs it.
- [x] Store `preparer` becomes a value (`Preparer a`), so it's built once per type.
- [x] Cookie options pass through too; our secure defaults (open question 1: kept) are merged in the FFI. `SameSite` is a newtype over Solid's string.
- [x] One `forImpl` and one `showMaybeImpl` taking `keyed`. Drop `untrackImpl`. Share the server-function guard.
- [x] Control fallbacks: `*Else` variants for every list (`forEachUnkeyedElse`, `forEachByElse`, `repeatElse`); open question 5 resolved that way.

Result: create 1k 19.8 → 19.1 ms, append 20.6 → 19.1 ms, 10k 214.5 → 203.6 ms, bundle 99.6 → 97.3 kB.

### Phase 2 — Measured performance experiments
- [x] Eager static children (finding 2): kept (open question 6). Hydration, SSR and every suite pass. Create 10k went 204.2 → 183.5–190.7 ms; 1k operations are within noise.
- [x] Re-profiled after Phase 1. Per clear + create 1k cycle, purs-solid now takes ~1.0 ms (was ~1.9) and `@solidjs/signals` ~1.7 ms (was ~2.5). What's left is Solid's `spread` / `assign` and native DOM work.

### Phase 3 — Errors and async correctness
- [x] `onError` on `renderWith` / `hydrateWith` (with `renderId`, `owner`) and in the SSR `RenderOptions`. `Either Error` still means a failure while starting the render; later render errors go to `onError`.
- [x] `Solid.Errors`: `configureClientErrors`, `configureServerErrors`, `resetErrorHalt`, `markSafeError`, `isSafeError`.
- [x] `affects` as an `Action` step, on a `Refresh a` (Solid only marks real memos, not derived accessors) and on a `Store` (`Store.affects`). `until` / `untilWith { timeout }` as an `Aff`; killing the fiber aborts it.
- [x] `clientOnly "name" load` (`lazy` was done in Phase 0).
- [x] Test support: `expectDiagnostic` acknowledges the code, so the enclosing `solidIt` doesn't report it.

### Phase 4 — Mutations and server responses
- [x] `Solid.Router.Action`: `routerAction`, `serverAction`, `formAction`, `useAction`, `useSubmissions`. Open question 2: two APIs. `Solid.Action` is Solid's transactional `action` (steps, optimistic values); router actions wrap it for form posts, submissions and revalidation.
- [x] `Reply` with `reply`, `redirect(With)`, `reload(With)`, `respond(With)`. `useAction` gives `Maybe b` because a redirect or reload has no value.
- [x] `call` / `callWith { keepalive }` go through `invoke`, with an `AbortSignal` aborted when the `Aff` fiber is killed.
- [x] `Middleware`: `next` takes the request, so a rewritten one can be passed on.
- [x] `RequestEvent`: `setResponseStatus`, `setResponseHeader`, `appendResponseHeader`, `deleteCookie`, cookie `partitioned`. `httpStatusText`.

### Phase 5 — Router data and navigation
- [x] `routeWith` / `layoutWith { preload }` (params typed), `Query.prefetch`, and `Control.loadingOn` (Loading's `on`).
- [x] Typed params (open question 3: syntax in the path). `:id<int>` is an `Int`, matched by the router's `int` filter. The pattern is parsed in JS; the PureScript `ParamFields` class is gone.
- [x] `useSearchParams` / `setSearchParams(With)`, `queryParams`, `locationState`, `locationKey`, `NavigateOptions.state`.
- [x] `useBeforeLeave`, `useLinkState`, `usePreloadRoute`, `useResolvedPath`.
- [x] `RouterOptions`: `preload`, `singleFlight`, `actionBase`, `explicitLinks`, `preloadLinks`, `scrollRestoration`, `transformUrl`.
- [x] `layoutLazy` (a module exporting `routes`); `QueryKey`, `queryKey(For)`, `revalidateKeys`, and `Reply` revalidation takes `QueryKey`s. `force` is already the router's default.
- [x] Router action `onSubmit` (optimistic writes in `Submitting`) and `onSettled`. `setOptimistic` / `modifyOptimistic` work in any `MonadOptimistic`.

### Phase 6 — Async, store and option completeness
- [x] Option rows: signals `ownedWrite`, `unobserved`; memos `unobserved`, `id`, `transparent`; effects `schedule`, `transparent`; async values `loadingValue` (encoded with a codec), `lazy`, `unobserved`; `createRootWith { id, transparent }`.
- [x] `createDerivedStore` (function-form `createStore`) and `createProjectionAsync` with a `Refresh` (the `Aff` is killed when its inputs change).
- [x] `reconcileByPosition` (`key: null`). String keys are covered by `reconcileBy`.
- [x] `createWritableMemoWith`, `createOptimisticWith`, `createOptimisticFromWith`, `Utility.repeatFrom`, `createNamedContext`, `Component.childrenArray`.
- [x] `StreamOptions` (`onCompleteShell`, `onCompleteAll`, `signal`) for the async and streamed renders; hydration script `eventNames`.
- Not bound: `ssrSource` on sync memos, `"hybrid"` (needs async-iterable sources), `mapArray` `fallback` / `name` (the `*Else` control functions cover fallbacks), serializer `plugins`, asset `manifest`.

### Phase 7 — PureScript developer experience
- [x] `Serializable` has no catch-all: newtypes derive it, and `Json` / `Object` are included. `Fail` instances give clear errors for `Maybe`, `Either`, functions and `Effect`. No PureScript codecs.
- [x] `Solid.DOM.targetValue` / `targetChecked` (one-line FFI on `currentTarget`); TodoMVC uses them.
- [x] `jsElement`: any prop can be left out (`Row.Union`).
- [x] `Store.focusKey @"x"` / `Store.atKey @"x"`.
- [x] `Solid.DOM.styleProp` merges like `classWhen` (with other `styleProp`s and `P.style`); `textContent`.
- [x] `Solid.Testing` in the library (open question 4), with no test-framework dependency: `mount`, `mountUsing`, `settle`, `html`, `query`, `click`, `inputText`, `collectDiagnostics`, `ignoreDiagnostic`. `Test.Solid` keeps only the spec wrappers.

### Phase 8 — Packaging and CI
- [x] CI workflow (`.github/workflows/ci.yml`): format check, `test:all` and `test:purescript:es`.
- [x] `purs-tidy` config and `format` / `format:check` scripts; PureScript, Spago and purs-tidy pinned as dev dependencies.
- [x] spago `publish` config (version 0.1.0, ISC) and LICENSE.
- [x] Re-checked the npm pins: `solid-js` / `@solidjs/web` rc.13, router next.32, vite-plugin next.47. Every suite passes on them.

## Intentionally not bound

- `merge` / `omit`: props are records.
- `createTrackedEffect`: deprecated, and breaks design rule 1.
- `createErrorBoundary` / `createLoadingBoundary` / `createRevealOrder`: the control-flow functions cover them.
- `storePath`: typed paths replace it, and it's not in `solid-js` rc.11.
- `defineRoute(s)` / `Router.paths`: TypeScript typing helpers, replaced by `route @path` / `href`.
- Internal and dev exports: `enableExternalSource`, `flatten`, `getObserver`, `$TRACK`, `DEV`/`OBSERVE`, performance tracks.
- `enableRichArguments` and `live` / `GET`: unless Phase 7 needs them.

## Open questions

1. ~~**Cookie defaults.**~~ Kept as a secure default, merged in the FFI (Phase 1).
2. ~~**Mutations.**~~ Two APIs (Phase 4).
3. ~~**Typed params.**~~ Syntax in the path, `:id<int>` (Phase 5).
4. ~~**Testing helpers.**~~ In the library, as `Solid.Testing` (Phase 7).
5. ~~**Control fallbacks.**~~ `*Else` variants everywhere (Phase 1).
6. ~~**Eager children.**~~ Kept (Phase 2).
