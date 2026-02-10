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
- `Solid.DOM.Events`
  - `handler`
  - `handler_`

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

`Solid.DOM` starts as a pragmatic MVP:

- generic constructors (`element`, `element_`)
- small high-frequency HTML constructor set
- event handler helpers in `Solid.DOM.Events`

Then it scales to generated full HTML/SVG coverage.

Reason:

- unblocks immediate UI authoring and browser smoke coverage
- preserves a path to high-DX breadth similar to `react-basic-dom` without sacrificing Solid-native semantics

### 15) Compatibility target is behavior, not React API shape

When comparing against `purescript-react-basic` and `purescript-react-basic-hooks` tests, we target equivalent developer outcomes and behavior, not React hook naming or lifecycle shape.

Examples:

- `useState` test intent maps to `createSignal` local state behavior
- `useReducer` test intent maps to explicit dispatch functions over signals/stores
- `memo`/`memo'` test intent maps to `createMemoWith` equality behavior

This keeps the package Solid-native while still delivering familiar DX guarantees (state updates, event-driven interactions, controlled recomputation).

## Non-goals (for now)

- router integration

These can be added incrementally after core reactive primitives are stable.

## Next Recommended Steps

1. Add generated HTML/SVG constructor coverage and richer `Solid.DOM.Events` extractors.
2. Add control-flow wrappers (`Show`, `For`, `Index`, `Switch`, `Dynamic`) as Solid-native modules.
3. Add async-focused resource tests for pending/refreshing transitions.
4. Add an SSR-backed hydrate success smoke test (in addition to current non-SSR classification checks).
