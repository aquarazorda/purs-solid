# purs-solid Implementation Plan

This is a living plan for building SolidJS wrappers in PureScript.

We will update this file as features are implemented, changed, or de-scoped.

## Goal

Provide a Solid-native PureScript API that preserves Solid semantics (fine-grained reactivity, ownership, lifecycle, rendering behavior) with strong types and minimal FFI leakage.

Design principles are documented in `DECISIONS.md`.

## Tracking Conventions

- `[x]` implemented and tested
- `[~]` in progress
- `[ ]` not started

## Current Snapshot

### Foundation (done)

- [x] `Solid.Signal`
  - [x] `createSignal`
  - [x] `createSignalWith`
  - [x] `get`, `set`, `modify`
  - [x] equality ADT (`DefaultEquals`, `AlwaysNotify`, `CustomEquals`)
- [x] `Solid.Reactivity`
  - [x] `createMemo`
  - [x] `createMemoWith`
  - [x] `createEffect`
  - [x] `createComputed`
  - [x] `createRenderEffect`
  - [x] `createReaction`
  - [x] `createDeferred`
  - [x] `createSelector`
- [x] `Solid.Root`
  - [x] `createRoot`
- [x] `Solid.Utility`
  - [x] `batch`
  - [x] `untrack`
  - [x] `on`
  - [x] `onWith`
  - [x] `getOwner`
  - [x] `runWithOwner`
- [x] `Solid.Lifecycle`
  - [x] `onCleanup`
  - [x] `onMount`
- [x] `Solid.Resource`
  - [x] `createResource`
  - [x] `createResourceFrom`
  - [x] resource accessors (`value`, `latest`, `state`, `loading`, `error`)
  - [x] resource actions (`mutate`, `refetch`)
- [x] `Solid.Context`
  - [x] `createContext`
  - [x] `createContextWithDefault`
  - [x] `useContext`
  - [x] `withContext`
- [x] `Solid.Store`
  - [x] `createStore`
  - [x] typed top-level field operations (`getField`, `setField`, `modifyField`)
  - [x] path update helpers (`setPath`, `modifyPath`)
  - [x] `createMutable` + mutable field/path helpers
  - [x] unwrap helpers (`unwrapStore`, `unwrapMutable`)
- [x] `Solid.Web`
  - [x] `render`
  - [x] `hydrate`
  - [x] `isServer`
  - [x] mount lookup helpers (`documentBody`, `mountById`, `requireBody`, `requireMountById`)

## Milestone Plan

### M1: Core Reactive Utilities

Docs references:

- https://docs.solidjs.com/reference/reactive-utilities/batch
- https://docs.solidjs.com/reference/reactive-utilities/untrack
- https://docs.solidjs.com/reference/reactive-utilities/on-util

Tasks:

- [x] Add `Solid.Utility.batch`
  - Files: `src/Solid/Utility.purs`, `src/Solid/Utility.js`
- [x] Add `Solid.Utility.untrack`
  - Files: `src/Solid/Utility.purs`, `src/Solid/Utility.js`
- [x] Add `Solid.Utility.on` (explicit dependency helper)
  - Files: `src/Solid/Utility.purs`, `src/Solid/Utility.js`
- [x] Add tests for batching behavior and explicit dependency behavior
  - File: `test/Test/Main.purs`
  - Scenarios: `unbatched updates run downstream effect twice`, `batched updates run downstream effect once`, `untrack reads do not subscribe`, `onWith defer skips initial execution`

Acceptance:

- [x] Batched updates trigger downstream effects once per batch
- [x] `untrack` reads do not subscribe
- [x] `on` can defer initial execution and reacts to dependency changes

### M2: Lifecycle and Ownership

Docs references:

- https://docs.solidjs.com/reference/lifecycle/on-cleanup
- https://docs.solidjs.com/reference/lifecycle/on-mount
- https://docs.solidjs.com/reference/reactive-utilities/get-owner
- https://docs.solidjs.com/reference/reactive-utilities/run-with-owner

Tasks:

- [x] Add `Solid.Lifecycle.onCleanup`
  - Files: `src/Solid/Lifecycle.purs`, `src/Solid/Lifecycle.js`
- [x] Add `Solid.Lifecycle.onMount`
  - Files: `src/Solid/Lifecycle.purs`, `src/Solid/Lifecycle.js`
- [x] Add owner utilities (`getOwner`, `runWithOwner`)
  - Files: `src/Solid/Utility.purs`, `src/Solid/Utility.js`
- [x] Add disposal/cleanup tests
  - File: `test/Test/Main.purs`
  - Scenarios: `getOwner outside reactive context should return Nothing`, `onCleanup runs on root disposal`, `onMount executes once after initial setup`, `runWithOwner transfers owner for cleanup registration`

Acceptance:

- [x] Cleanup runs on root disposal
- [x] Mount callback executes once after initial setup
- [x] Owner transfer works with `runWithOwner`

### M3: Secondary Primitives

Docs references:

- https://docs.solidjs.com/reference/secondary-primitives/create-computed
- https://docs.solidjs.com/reference/secondary-primitives/create-render-effect
- https://docs.solidjs.com/reference/secondary-primitives/create-reaction
- https://docs.solidjs.com/reference/secondary-primitives/create-deferred
- https://docs.solidjs.com/reference/secondary-primitives/create-selector

Tasks:

- [x] Add `createComputed`
  - Files: `src/Solid/Reactivity.purs`, `src/Solid/Reactivity.js`
- [x] Add `createRenderEffect`
  - Files: `src/Solid/Reactivity.purs`, `src/Solid/Reactivity.js`
- [x] Add `createReaction`
  - Files: `src/Solid/Reactivity.purs`, `src/Solid/Reactivity.js`
- [x] Add `createDeferred`
  - Files: `src/Solid/Reactivity.purs`, `src/Solid/Reactivity.js`
- [x] Add `createSelector`
  - Files: `src/Solid/Reactivity.purs`, `src/Solid/Reactivity.js`

Acceptance:

- [x] Execution timing differences between effect kinds are covered by tests
- [x] Selector behavior updates only relevant dependents
  - File: `test/Test/Main.purs`
  - Scenarios: `createComputed runs for each synchronous update`, `createRenderEffect batches updates during setup`, `createEffect initial run happens after setup updates`, `selector skips unaffected row 3`

### M4: Async Reactivity (Resources)

Docs reference:

- https://docs.solidjs.com/reference/basic-reactivity/create-resource

Tasks:

- [x] Add resource wrapper module with typed state/accessors/actions
  - Files: `src/Solid/Resource.purs`, `src/Solid/Resource.js`
- [x] Model `Resource` states (`unresolved`, `pending`, `ready`, `refreshing`, `errored`)
  - File: `src/Solid/Resource.purs`
- [x] Add `mutate` and `refetch` actions
  - Files: `src/Solid/Resource.purs`, `src/Solid/Resource.js`
- [x] Add tests for success, error, and refetch flows
  - File: `test/Test/Main.purs`
  - Scenarios: `sourced resource becomes ready after source appears`, `resource enters errored state after failing fetch`, `resource returns to ready state after recovery`, `manual refetch triggers fetcher`

Acceptance:

- [x] Resource state transitions match Solid behavior
- [x] Type-level API clearly represents possibly-uninitialized values
  - `value` and `latest` are `Either ResourceReadError (Maybe a)` in `Solid.Resource`
  - `state` is `Either ResourceStateError ResourceState` in `Solid.Resource`

### M5: Context API

Docs references:

- https://docs.solidjs.com/reference/component-apis/create-context
- https://docs.solidjs.com/reference/component-apis/use-context

Tasks:

- [x] Add `createContext`
  - Files: `src/Solid/Context.purs`, `src/Solid/Context.js`
- [x] Add `useContext`
  - Files: `src/Solid/Context.purs`, `src/Solid/Context.js`
- [x] Define default-value and `Maybe` strategy for PureScript ergonomics
  - File: `src/Solid/Context.purs`
  - Shape: `createContext` (no default), `createContextWithDefault`, `useContext :: Context a -> Effect (Maybe a)`
- [x] Add tests for provider/no-provider scenarios
  - File: `test/Test/Main.purs`
  - Scenarios: `context without provider returns Nothing`, `context default value is returned without provider`, `withContext provides value within current scope`, `context value is inherited by nested ownership scope`

Acceptance:

- [x] Context values resolve correctly in nested ownership scopes
- [x] Missing provider behavior is explicit in types or documented runtime behavior

### M6: Stores

Docs references:

- https://docs.solidjs.com/reference/store-utilities/create-store
- https://docs.solidjs.com/reference/store-utilities/create-mutable
- https://docs.solidjs.com/reference/store-utilities/produce
- https://docs.solidjs.com/reference/store-utilities/reconcile
- https://docs.solidjs.com/reference/store-utilities/unwrap

Tasks:

- [x] Introduce `Solid.Store` module (or package split if needed)
  - Files: `src/Solid/Store.purs`, `src/Solid/Store.js`
- [x] Wrap `createStore` with practical PureScript path/update API
  - Files: `src/Solid/Store.purs`, `src/Solid/Store.js`
  - API: typed top-level field helpers plus dynamic path helpers
- [x] Evaluate `createMutable` support and mutability guarantees
  - Files: `src/Solid/Store.purs`, `src/Solid/Store.js`, `DECISIONS.md`
- [x] Add tests for nested updates and structural sharing behavior
  - Files: `test/Test/Main.purs`, `test/Test/Main.js`
  - Scenarios: `store modifyPath updates nested value`, `store preserves untouched branch reference`, `store setField with object keeps branch reference and merges fields`, `mutable nested updates keep branch reference`

Acceptance:

- [x] Store updates are ergonomic and type-safe
- [x] Proxy-backed behavior is documented with caveats

### M7: Rendering Entry Points

Docs references:

- https://docs.solidjs.com/reference/rendering/render
- https://docs.solidjs.com/reference/rendering/hydrate
- https://docs.solidjs.com/reference/rendering/is-server

Tasks:

- [x] Decide module layout for web-specific APIs (likely `Solid.Web`)
  - Files: `src/Solid/Web.purs`, `src/Solid/Web.js`
- [x] Add `render` and returned disposer wrapper
  - Files: `src/Solid/Web.purs`, `src/Solid/Web.js`
- [x] Add `hydrate` and `isServer`
  - Files: `src/Solid/Web.purs`, `src/Solid/Web.js`
- [x] Add browser integration smoke tests
  - Files: `test/browser/smoke.html`, `test/browser/smoke-client.mjs`, `test/browser/run-smoke.mjs`, `package.json`
  - Coverage: real Chromium smoke checks for `documentBody`, `mountById`, `requireBody`, `requireMountById`, browser `render` mount/dispose behavior, and `hydrate` result classification
  - Commands: `npm run test:browser-smoke` (includes `spago test`)

Acceptance:

- [x] Minimal browser app entrypoint works from PureScript
- [x] SSR-related APIs are clearly separated from core runtime wrappers

## Cross-Cutting Tasks

- [ ] Improve docs for every exported symbol with short examples
- [ ] Add property tests for equality behavior and signal updates
- [ ] Add CI command matrix (`spago test`, lint, formatting if added)
- [ ] Verify runtime import strategy and document any environment caveats

## Proposed Module Layout

- `Solid.Signal`
- `Solid.Reactivity`
- `Solid.Root`
- `Solid.Utility` (batch, untrack, on, owner helpers)
- `Solid.Lifecycle`
- `Solid.Resource`
- `Solid.Context`
- `Solid.Store`
- `Solid.Web` (render/hydrate/isServer)

## How To Update This Plan

Whenever a task is implemented:

1. Mark the checkbox as done.
2. Add file paths that implemented the task.
3. Add test names or scenarios that verify behavior.
4. If API shape changed, update `DECISIONS.md` and this plan together.
