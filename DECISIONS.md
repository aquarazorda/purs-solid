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
- `Solid.Root`
  - `createRoot`

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

## Non-goals (for now)

- JSX/view DSL
- component rendering helpers
- router integration
- stores/resources/context wrappers

These can be added incrementally after core reactive primitives are stable.

## Next Recommended Steps

1. Add `batch` and `untrack` wrappers.
2. Add `onCleanup` and richer effect helpers.
3. Add focused tests for memo equality and effect scheduling semantics.
4. Define a rendering layer that stays Solid-native in naming and behavior.
