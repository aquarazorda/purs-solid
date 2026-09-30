# Plan: FFI-first bindings, Solid 2 coverage, developer experience

Status: in progress on `main`, planned 2026-09-30. Source: a review of the code, the compiled output and a CPU profile, plus a comparison of every export in the Solid 2 reference (v2.solidjs.com) against the pinned packages (`solid-js` / `@solidjs/web` rc.11, router next.31, meta next.2, vite-plugin next.46).

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
- [ ] Options pass through as optional-field records:
  - `createSignalWith`, `createMemoWith`, `createEffectWith`, `createAsyncWith`;
  - the SSR render options, `RouterConfig`, `navigateWith`.

  Delete the `default*Options` records. Callback fields are typed as `EffectFn`s so they pass as is.
- [ ] `Equality` becomes a foreign type holding Solid's `equals` value (`false` or a function). Delete `toEqualityFn` and the three `equalityOptions` copies.
- [ ] `ToBinding` becomes a method-less constraint. The FFI dispatches on `typeof v === "function"` (attribute values are never functions). Delete `Binding` and `bindingProp`'s PureScript branch.
- [ ] Enums become foreign constants: `RevealOrder`, `SameSite`, `Namespace`, `AsyncSsr`.
- [ ] `href`: keep the type-level parsing and move rendering to JS (native `encodeURIComponent`, parsed pattern cached). Drop `js-uri` if nothing else needs it.
- [ ] Store `preparer` becomes a value (`Preparer a`), so it's built once per type.
- [ ] One `forImpl` and one `showMaybeImpl` taking `keyed`. Drop `untrackImpl`. Share the server-function guard.
- [ ] Control fallbacks: one consistent form for every list and conditional (see open question 5).

### Phase 2 — Measured performance experiments
- [ ] Eager static children (finding 2). Keep it only if `test:hydration` and the SSR specs pass.
- [ ] Re-profile after Phase 1. Look for remaining per-element PureScript overhead (identity `toAttrValue` maps, closure layers in `realize`).

### Phase 3 — Errors and async correctness
- [ ] `onError` on `render`, `hydrate` and the SSR functions. Then decide what `Either Error` still means there (finding 6).
- [ ] `configureClientErrors` / `resetErrorHalt`; `markSafeError` / `isSafeError`.
- [ ] `affects`; `until` as `Aff`.
- [ ] `clientOnly`. (`lazy` was done in Phase 0.)

### Phase 4 — Mutations and server responses
- [ ] Router `action`, `useAction`, `useSubmissions`, and their relation to `Solid.Action` (open question 2).
- [ ] `redirect`, `reload`, `respond`.
- [ ] `call` through `invoke`, with an `AbortSignal` aborted when the `Aff` fiber is killed.
- [ ] `Middleware`: `next` accepts a rewritten `Request`.
- [ ] `RequestEvent`: response status and headers, cookie `expires` / `partitioned`, cookie deletion. `httpStatus` status text.

### Phase 5 — Router data and navigation
- [ ] Route `preload`, and `Loading`'s `on` for route-change skeletons.
- [ ] `matchFilters` with the router's `int`, giving typed `Int` params (open question 3).
- [ ] `useSearchParams` with a setter; `Location` query, `state` and `key`; `NavigateOptions.state`.
- [ ] `useBeforeLeave`, `useLinkState`, `usePreloadRoute`, `useResolvedPath`.
- [ ] Remaining `RouterConfig` options: `preload`, `singleFlight`, `actionBase`, `explicitLinks`, `preloadLinks`, `scrollRestoration`, `transformUrl`.
- [ ] Lazy route children; `revalidate` with `force` and several keys.

### Phase 6 — Async, store and option completeness
- [ ] Computation options, which become row fields after Phase 1:
  - `ownedWrite`, `unobserved`, `schedule`, `transparent`;
  - `ssrSource` (`"client"` / `"hybrid"`), `loadingValue`, `deferStream`, `lazy`;
  - `createRoot` `id`.
- [ ] Function-form `createStore(fn, seed)` with a `Refresh`; async `createProjection` with `seedLoadingValue`.
- [ ] `reconcile`: positional (`key: null`) and string keys.
- [ ] Options for `createWritableMemo`, `createOptimistic(From)`, `mapArray*` (`fallback`, `name`), `repeat` (`from`) and `createContext` (`name`).
- [ ] `children` `toArray`.
- [ ] Stream options: `onCompleteShell`, `onCompleteAll`, `signal`; hydration script `eventNames`; serialization `plugins`, `manifest`.

### Phase 7 — PureScript developer experience
- [ ] `Serializable`: drop the catch-all so newtypes can derive it. Keep `Fail` instances only for the common mistakes (`Maybe`, `Either`, functions, `Effect`), which don't overlap with user types. No PureScript codecs.
- [ ] Event helpers as one-line FFI (`inputValue`, `inputChecked`, …) to replace `target event >>= fromEventTarget` + `traverse_`.
- [ ] `jsElement`: optional props can be left out (`Row.Union`, or separate required and optional rows).
- [ ] Store path shortcuts, e.g. `Store.field @"x"` for `at (key @"x")` / `focus (key @"x")`, and a one-call read at a path.
- [ ] `style` that merges like `classWhen` (object form); `textContent` prop.
- [ ] `Solid.Testing` from `test/Test/Solid.purs`: `mount`, `settle`, `click`, `inputText`, diagnostics collection (open question 4).

### Phase 8 — Packaging and CI
- [ ] CI workflow running `test:all` and `test:purescript:es`.
- [ ] `purs-tidy` config.
- [ ] spago `publish` config and LICENSE.
- [ ] Re-check the npm pins (the RC and the router move fast).

## Intentionally not bound

- `merge` / `omit`: props are records.
- `createTrackedEffect`: deprecated, and breaks design rule 1.
- `createErrorBoundary` / `createLoadingBoundary` / `createRevealOrder`: the control-flow functions cover them.
- `storePath`: typed paths replace it, and it's not in `solid-js` rc.11.
- `defineRoute(s)` / `Router.paths`: TypeScript typing helpers, replaced by `route @path` / `href`.
- Internal and dev exports: `enableExternalSource`, `flatten`, `getObserver`, `$TRACK`, `DEV`/`OBSERVE`, performance tracks.
- `enableRichArguments` and `live` / `GET`: unless Phase 7 needs them.

## Open questions

1. **Cookie defaults.** `defaultCookieOptions` (`HttpOnly`, `Secure`, `SameSite=Lax`) is our policy, not Solid's. Keep it as a secure default, or pass through?
2. **Mutations.** One `Action` API over core `action` and the router's form-bound `action`, or two?
3. **Typed params.** Where do filters go: a filters record next to `route @"/users/:id"`, or syntax in the path (`@"/users/:id<int>"`) parsed at the type level?
4. **Testing helpers.** In the library, or a separate package?
5. **Control fallbacks.** `*Else` variants for every list and conditional, or a single form that takes the fallback?
6. **Eager children.** If it passes hydration, is ~5% on creation worth the changed realization order?
