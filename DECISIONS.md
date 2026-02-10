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

## Non-goals (for now)

- JSX/view DSL
- component rendering helpers
- router integration

These can be added incrementally after core reactive primitives are stable.

## Next Recommended Steps

1. Add real browser DOM smoke tests for `Solid.Web` render/hydrate mount/dispose behavior.
2. Add async-focused resource tests for pending/refreshing transitions.
3. Improve docs and examples for all newly added modules.
4. Add CI matrix steps for `spago test` and formatting/lint checks.
