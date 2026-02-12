# purs-solid: Goal and Design Decisions

## Package Goal

`purs-solid` provides a PureScript-first wrapper over Solid's fine-grained reactivity primitives.

The goal is to expose Solid behavior through strong, explicit PureScript types while keeping the FFI surface small and predictable.

## Scope Right Now

Current primitives are focused on reactive core building blocks:

- `Solid.Signal`
  - `createSignal`
  - `createSignalWith`
  - `get`
  - `set`
  - `modify`
- `Solid.Reactivity`
  - `createMemo`
  - `createMemoWith`
  - `createEffect`
  - `createComputed`
  - `createRenderEffect`
  - `createReaction`
  - `createDeferred`
  - `createSelector`
- `Solid.Root`
  - `createRoot`
- `Solid.Utility`
  - `batch`
  - `untrack`
  - `on`
  - `onWith`
  - `getOwner`
  - `runWithOwner`
- `Solid.Lifecycle`
  - `onCleanup`
  - `onMount`
- `Solid.Resource`
  - `createResource`
  - `createResourceFrom`
  - resource accessors (`value`, `latest`, `state`, `loading`, `error`)
    - functional reads: `value` and `latest` return `Either ResourceReadError (Maybe a)`
    - functional state decode: `state` returns `Either ResourceStateError ResourceState`
  - resource actions (`mutate`, `refetch`)
- `Solid.Context`
  - `createContext`
  - `createContextWithDefault`
  - `useContext`
  - `withContext`
- `Solid.Store`
  - `createStore`
  - typed field helpers (`getField`, `setField`, `modifyField`)
  - path helpers (`setPath`, `modifyPath`)
  - `createMutable` and mutable field/path helpers
  - unwrap helpers (`unwrapStore`, `unwrapMutable`)
- `Solid.Web`
  - `render`
  - `hydrate`
  - `isServer`
  - mount lookup helpers (`documentBody`, `mountById`, `requireBody`, `requireMountById`)
- `Solid.JSX`
  - `empty`
  - `text`
  - `fragment`
  - `keyed`
- `Solid.Component`
  - `component`
  - `element`
  - `elementKeyed`
- `Solid.DOM` (MVP)
  - generic element constructors (`element`, `element_`)
  - minimal HTML constructors (`div`, `span`, `button`, `input`, `form`, `ul`, `li`)
- `Solid.DOM.HTML`
  - full HTML constructor set (`tag` and `tag_` variants)
  - `dataTag` / `dataTag_` for `<data>`
- `Solid.DOM.SVG`
  - full SVG constructor set (`tag` and `tag_` variants)
  - hyphenated SVG tag mapping via camelCase constructors (`fontFace`, `colorProfile`, `missingGlyph`, ...)
- `Solid.DOM.Events`
  - `handler`
  - `handler_`
  - uses `web-events` package `Web.Event.Event` type
  - keeps only thin handler helpers
- `Solid.DOM.EventAdapters`
  - optional ergonomics over ecosystem web packages
  - casts/reads through `web-uievents`, `web-html`, `web-dom`, `web-file`
  - includes input/keyboard/mouse/drag/composition adapter helpers
- `Solid.Control`
  - conditionals (`when`, `whenElse`)
  - list control (`forEach`, `forEachElse`, `forEachWithIndex`, `forEachWithIndexElse`, `indexEach`, `indexEachElse`)
  - branching (`matchWhen`, `matchWhenKeyed`, `switchCases`, `switchCasesElse`)
  - dynamic/portal (`dynamicTag`, `dynamicComponent`, `portal`, `portalAt`)

No React-style API layer is included. The package intentionally uses Solid naming and Solid mental model.

## Key Decisions

### 1) Solid-native naming only

We do not expose `use*` or `React.*` style APIs. Public names follow Solid primitives (`createSignal`, `createMemo`, `createEffect`, `createRoot`).

### 2) Opaque accessor/setter types

Signals are represented as:

- `Accessor a`
- `Setter a`
- `Signal a = Accessor a /\ Setter a`

`Accessor` and `Setter` are opaque FFI data types. This prevents invalid direct construction from PureScript and keeps runtime semantics aligned with Solid.

### 3) Tuple signal shape

Signals are returned as tuples (`Accessor /\ Setter`) to mirror Solid's getter/setter pair.

### 4) Explicit update functions for setters

Setter helpers are separated:

- `set :: Setter a -> a -> Effect a`
- `modify :: Setter a -> (a -> a) -> Effect a`

`set` is implemented in FFI with `setter(() => value)` so function-valued signals are treated as values, not updater callbacks.

### 5) Equality options encoded as an ADT

Signal and memo equality behavior uses:

- `DefaultEquals`
- `AlwaysNotify`
- `CustomEquals (a -> a -> Boolean)`

This replaces JS union-style options with explicit PureScript constructors.

### 6) `Effect`-based reactive callbacks

`createMemo` and `createEffect` accept `Effect` callbacks so reactive reads happen through `get` while Solid tracking is active.

Example pattern:

```purescript
doubled <- createMemo do
  n <- get count
  pure (n * 2)

createEffect do
  current <- get doubled
  logShow current
```

### 7) Runtime import choice

FFI imports Solid from `solid-js/dist/solid.js`.

Reason: this package targets client-style fine-grained reactivity behavior during local Node-based tests as well, and this import path preserves expected signal/memo update behavior for the current setup.

### 8) Store update semantics and mutable caveats

`Solid.Store` follows Solid Store behavior: object updates merge into existing branches by default, including top-level `setField` when the new value is an object.

Implications:

- branch references may remain stable for nested/object updates
- untouched branches stay reference-stable
- replacing object branches requires explicit non-merge patterns

`createMutable` is exposed as an opt-in mutable escape hatch. It is practical for interop and imperative updates but should be used carefully because updates are in-place and can bypass immutable-style reasoning.

### 9) Web wrappers use environment-aware imports

`Solid.Web` imports from `solid-js/web` (package entry), not `solid-js/web/dist/web.js` directly.

Reason: this keeps server/client behavior aligned with Solid's export conditions.

- in server-like runtimes, `isServer` is `true` and `render`/`hydrate` return `Left (ClientOnlyApi ...)`
- in browser runtimes, `render`/`hydrate` return `Right disposer` on success

Browser smoke tests run in real Chromium via Playwright and load generated `output/*` modules directly over HTTP with an import map for bare Solid specifiers.

### 10) Functional error handling policy (for future modules too)

Public APIs model failure explicitly in return types.

Policy:

- prefer `Either ErrorType a` for recoverable runtime failures
- use `Maybe a` only for expected absence (`no provider`, `no mount node`, etc.)
- avoid throwing from public wrappers; convert JS exceptions in FFI into typed `Left` values
- keep error representation close to domain (`WebError`, `ResourceReadError`, `ResourceStateError`)

This policy applies to all future wrappers (`Solid.Web`, `Solid.Resource`, and upcoming modules) unless there is a hard runtime constraint that makes typed recovery impossible.

### 11) Pre-1.0 API evolution policy

This package currently prioritizes correctness, explicit types, and functional design over API stability.

Policy:

- no backwards-compatibility guarantees before 1.0
- no deprecation/shim layer by default during early development
- when an API can be made more principled (for example, replacing exceptions with `Either`), rewrite it directly
- keep `DECISIONS.md` and tests aligned with the latest canonical API shape

### 12) Test entrypoints

- PureScript suite: `spago test`
- Browser smoke suite: `npm run test:browser-smoke`
- Combined local run: `npm run test:all`

### 13) Solid-native component setup model

Components are defined as setup functions with this shape:

- `props -> Effect JSX`

and lifted into renderable component values via `Solid.Component.component`.

Reason:

- aligns with Solid's setup + fine-grained reactive mental model
- naturally composes with existing primitives (`createSignal`, `createEffect`, lifecycle/owner APIs)
- avoids introducing React hook semantics into this package

### 14) DOM authoring strategy

`Solid.DOM` started as a pragmatic MVP:

- generic constructors (`element`, `element_`)
- small high-frequency HTML constructor set
- event handler helpers in `Solid.DOM.Events`

Then it scales to generated full HTML/SVG coverage through `Solid.DOM.HTML` and `Solid.DOM.SVG`.

Event typing strategy: reuse ecosystem web packages (`web-events`, and later `web-uievents` / `web-html` / related packages) instead of growing bespoke event extractor APIs.

Reason:

- unblocks immediate UI authoring and browser smoke coverage
- preserves a path to high-DX breadth similar to `react-basic-dom` without sacrificing Solid-native semantics

### 15) Compatibility target is behavior, not React API shape

When comparing against `purescript-react-basic` and `purescript-react-basic-hooks` tests, we target equivalent developer outcomes and behavior, not React hook naming or lifecycle shape.

Examples:

- `useState` test intent maps to `createSignal` local state behavior
- `useReducer` test intent maps to explicit dispatch functions over signals/stores
- `memo`/`memo'` test intent maps to `createMemoWith` equality behavior
- `useMemo` dependency intent maps to `createMemo` tracked dependency behavior
- `useEffect` cleanup intent maps to `createEffect` + `onCleanup`

This keeps the package Solid-native while still delivering familiar DX guarantees (state updates, event-driven interactions, controlled recomputation).

### 16) Control-flow wrappers accept accessors and expose effectful render callbacks

`Solid.Control` wrappers are accessor-first for reactive inputs:

- `when` / `whenElse` receive `Accessor Boolean`
- `forEach` / `forEachWithIndex` / `indexEach` receive `Accessor (Array a)`
- keyed switch matching is available via `matchWhenKeyed`

Wrapper FFI uses JS getter props (`get when()`, `get each()`) so Solid tracks signal dependencies correctly.

List render callbacks are effectful (`a -> Effect JSX`, `Accessor a -> Effect JSX`) to keep authoring style consistent with setup/effect patterns already used across this package.

### 17) Reuse web platform packages instead of bespoke event extractors

`Solid.DOM.Events` is intentionally thin and based on ecosystem web types:

- event value type: `Web.Event.Event` from `web-events`
- wrapper surface: `handler`, `handler_`

Ergonomic extraction lives in `Solid.DOM.EventAdapters`, which is built on top of `web-uievents`, `web-html`, `web-dom`, and `web-file`.

Reason:

- avoids re-implementing browser API modeling in this package
- keeps maintenance focused on Solid-specific abstractions
- allows optional higher-level adapters on top of stable web package foundations

### 18) SolidStart-style file routing uses code generation, not runtime filesystem reads

PureScript route files are discovered by a Node generator (`scripts/gen-routes.mjs`) and emitted into a generated PureScript module:

- source convention (current example scaffold): `src/Examples/SolidStart/Routes/**/*.purs`
- generated output: `src/Solid/Start/Internal/Manifest.purs`

Reason:

- PureScript application code should stay pure/runtime-deterministic and avoid direct filesystem dependency
- manifest generation keeps route tables explicit and compiler-visible
- this preserves a file-based DX while still keeping routing runtime strongly typed

### 19) Route matching precedence is explicit and typed

`Solid.Start.Routing` models segments with an ADT (`Static`, `Param`, `Optional`, `CatchAll`) and computes best-match precedence from a deterministic score.

Current ordering intent:

- static segments outrank dynamic segments
- param segments outrank catch-all
- skipped optional segments are lower priority than exact static matches

This policy is validated by dedicated tests in `test/Test/Start/Routing.purs` and integration checks in `test/Test/Start/Manifest.purs`.

### 20) Middleware uses explicit functional composition (onion model)

`Solid.Start.Middleware` composes middleware as pure function layers over a typed `Next` handler:

- request flow: outer -> inner -> handler
- response flow: handler -> inner -> outer

Implication: response transforms from earlier middleware in the list run last (standard onion behavior). This is covered by tests in `test/Test/Start/Middleware.purs`.

### 21) SolidStart source-of-truth lives under `src/Examples/SolidStart`

The in-repo Start source and generated app split is:

- source-of-truth: `src/Examples/SolidStart/`
- generated runnable app: `examples/solid-start/`

Reason:

- keeps app behavior and route intent authored in PureScript
- keeps Start runtime glue generated and replaceable as upstream alpha evolves
- keeps the public runnable app location stable (`examples/solid-start/`) for DX and tooling

### 22) Route generation includes diagnostics for ambiguous dynamic shapes

`scripts/gen-routes.mjs` now emits warnings for:

- equivalent dynamic route shapes across multiple files
- optional/catch-all overlaps that can produce broad matching behavior

These diagnostics are advisory (non-fatal) and designed to catch accidental route ambiguity early while keeping development flow unblocked.

### 23) Runtime request/response adapters are kept explicit

`Solid.Start.Server.Runtime` bridges untyped runtime request/response values into typed Start request/response models.

Policy:

- decode runtime inputs into `Either StartError Request`
- map domain errors to typed responses deterministically
- keep conversion boundaries visible rather than hiding runtime object access in core logic

### 24) SolidStart example parity targets the upstream Hacker News fixture (alpha)

The reference behavior for the example app is the latest SolidStart Hacker News fixture:

- `solidjs/solid-start` `main` -> `apps/fixtures/hackernews`

Implementation policy:

- author app behavior in PureScript under `src/Examples/SolidStart`
- generate runnable Start app files into `examples/solid-start`
- keep JS/JSX runtime glue minimal and generated where possible

## Non-goals (for now)

- full production-grade SolidStart parity in one step
- locking to a single runtime host strategy too early while alpha APIs are still moving

These will be added incrementally as the `Solid.Start.*` surface matures.

## Next Recommended Steps

1. Add typed route param decoding helpers on top of `RouteParams`.
2. Expand server entry APIs to typed query/body/header decoding.
3. Add SSR-backed Start smoke tests for hydrate success and navigation.
4. Continue existing control-flow ergonomics work in `Solid.Control`.
