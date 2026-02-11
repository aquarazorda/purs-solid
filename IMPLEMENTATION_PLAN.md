# purs-solid Implementation Plan

This is a living plan for building SolidJS wrappers in PureScript.

We will update this file as features are implemented, changed, or de-scoped.

Note: SolidStart-focused planning and progress now live in `SolidStart/IMPLEMENTATION_PLAN.md`.

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
- [x] `Solid.JSX`
  - [x] `empty`
  - [x] `text`
  - [x] `fragment`
  - [x] `keyed`
- [x] `Solid.Component`
  - [x] `component`
  - [x] `element`
  - [x] `elementKeyed`
- [~] `Solid.DOM`
  - [x] generic constructors (`element`, `element_`)
  - [x] minimal HTML constructors (`div`, `span`, `button`, `input`, `form`, `ul`, `li`)
  - [x] event handler core (`Solid.DOM.Events.handler`, `handler_`)
  - [x] generated full HTML/SVG constructor coverage via submodules
- [x] `Solid.DOM.HTML`
  - [x] full HTML constructor surface (`tag` and `tag_` variants)
  - [x] reserved-keyword-safe data constructor (`dataTag`, `dataTag_`)
- [x] `Solid.DOM.SVG`
  - [x] full SVG constructor surface (`tag` and `tag_` variants)
  - [x] hyphenated tag mapping to camelCase names (`fontFace`, `colorProfile`, `missingGlyph`, etc.)
- [~] `Solid.Control`
  - [x] conditional wrappers (`when`, `whenElse`)
  - [x] list wrappers (`forEach`, `forEachElse`, `forEachWithIndex`, `forEachWithIndexElse`, `indexEach`, `indexEachElse`)
  - [x] branching wrappers (`matchWhen`, `matchWhenKeyed`, `switchCases`, `switchCasesElse`)
  - [x] dynamic wrappers (`dynamicTag`, `dynamicComponent`)
  - [x] portal wrappers (`portal`, `portalAt`)
  - [~] richer control-flow ergonomics (typed switch/list case helpers)

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
  - File: `test/Test/Lifecycle.purs`
  - Scenarios: `getOwner outside reactive context should return Nothing`, `onCleanup runs on root disposal`, `onMount executes once after initial setup`, `runWithOwner transfers owner for cleanup registration`, `effect cleanup runs before rerun on dependency change`

Acceptance:

- [x] Cleanup runs on root disposal
- [x] Mount callback executes once after initial setup
- [x] Owner transfer works with `runWithOwner`
- [x] Effect cleanup runs before rerun and on disposal

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
  - Files: `test/Test/Secondary.purs`, `test/Test/Signal.purs`
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

### M8: JSX and Component Core

Docs references:

- https://docs.solidjs.com/concepts/components/basics
- https://github.com/solidjs/solid/tree/main/packages/solid/h

Tasks:

- [x] Add `Solid.JSX` (`empty`, `text`, `fragment`, `keyed`)
  - Files: `src/Solid/JSX.purs`, `src/Solid/JSX.js`
- [x] Add `Solid.Component` (`component`, `element`, `elementKeyed`)
  - Files: `src/Solid/Component.purs`, `src/Solid/Component.js`
- [x] Add compile/runtime smoke coverage for UI core modules
  - Files: `test/Test/UI.purs`, `test/browser/smoke-client.mjs`

Acceptance:

- [x] Components can be defined as Solid-native setup functions (`props -> Effect JSX`)
- [x] JSX core values compose and render in browser smoke tests

### M9: Typed DOM Authoring (MVP)

Docs references:

- https://docs.solidjs.com/reference/jsx-attributes/classlist
- https://docs.solidjs.com/reference/jsx-attributes/style

Tasks:

- [x] Add minimal `Solid.DOM` constructors for common HTML authoring
  - Files: `src/Solid/DOM.purs`, `src/Solid/DOM.js`
- [x] Add event handler helpers (`Solid.DOM.Events`)
  - File: `src/Solid/DOM/Events.purs`
  - Shape: `EventHandler`, `handler`, `handler_`
- [x] Reuse ecosystem web event types instead of custom event extractor FFI
  - Files: `spago.yaml`, `spago.lock`, `src/Solid/DOM/Events.purs`
  - Package: `web-events`
- [x] Add optional package-backed event adapters for common ergonomics
  - Files: `src/Solid/DOM/EventAdapters.purs`, `test/Test/EventAdapters.purs`, `spago.yaml`, `spago.lock`
  - Packages: `web-uievents`, `web-html`, `web-dom`, `web-file`
  - Coverage: compile-level adapter API suite (`Event adapters tests starting`)
- [x] Add browser smoke coverage rendering through `Solid.DOM` + `Solid.Component`
  - File: `test/browser/smoke-client.mjs`
- [x] Add interaction smoke checks for signal-based local state patterns
  - File: `test/browser/smoke-client.mjs`
  - Scenarios: click-driven counter, function-valued signal counter, reducer-style dispatch counter, memo dependency stability/recompute behavior, effect cleanup on dependency changes
- [x] Add hooks-intent parity smoke checks using Solid-native APIs
  - File: `test/browser/smoke-client.mjs`
  - Mapping: `useState` -> `createSignal`, `useReducer` -> dispatch over signals, `memo`/`memo'` -> `createMemo`/`createMemoWith`, `useEffect` cleanup -> `createEffect` + `onCleanup`
- [x] Add generated full HTML/SVG constructor modules
  - Files: `src/Solid/DOM/HTML.purs`, `src/Solid/DOM/SVG.purs`
  - Coverage smoke: `test/browser/smoke-client.mjs` (`html-article`, `html-data`, `svg-root`, `svg-circle`)
- [x] Remove bespoke event extractor tranche and use browser/web packages instead
  - Action: dropped custom extractor FFI surface from `Solid.DOM.Events`
  - Coverage: browser smoke still validates event handling behavior through `handler` / `handler_`

Acceptance:

- [x] A simple UI tree can be authored with `Solid.DOM` and rendered in browser smoke tests
- [x] Interactive state updates work in browser via `Solid.Component` + `Solid.Signal`
- [~] DOM authoring ergonomics approach `react-basic-dom` breadth without unsafe user code

### M10: Control-Flow Wrappers (MVP)

Docs references:

- https://docs.solidjs.com/concepts/control-flow/conditional-rendering
- https://docs.solidjs.com/concepts/control-flow/list-rendering
- https://docs.solidjs.com/reference/components/switch-and-match
- https://docs.solidjs.com/reference/components/dynamic
- https://docs.solidjs.com/reference/components/portal

Tasks:

- [x] Add conditional wrappers (`when`, `whenElse`)
  - Files: `src/Solid/Control.purs`, `src/Solid/Control.js`
- [x] Add list wrappers (`forEach`, `indexEach`) with effectful render callbacks
  - Files: `src/Solid/Control.purs`, `src/Solid/Control.js`
- [x] Add branching wrappers (`matchWhen`, `matchWhenKeyed`, `switchCases`, `switchCasesElse`)
  - Files: `src/Solid/Control.purs`, `src/Solid/Control.js`
- [x] Add dynamic and portal wrappers (`dynamicTag`, `dynamicComponent`, `portal`, `portalAt`)
  - Files: `src/Solid/Control.purs`, `src/Solid/Control.js`
- [x] Add browser smoke coverage for control-flow interaction behavior
  - File: `test/browser/smoke-client.mjs`
  - Scenarios: `when` toggle behavior, `whenElse` fallback/content switching, `forEach`/`indexEach` append updates, `switchCases` branch switching, `dynamicTag`/`dynamicComponent` render
- [x] Add ergonomic helpers for keyed switch/list behavior
  - Files: `src/Solid/Control.purs`, `src/Solid/Control.js`
  - Added: `forEachWithIndex`, `forEachWithIndexElse`, `matchWhenKeyed`
- [ ] Add typed switch/list case constructors for larger control-flow trees

Acceptance:

- [x] Control wrappers react to signal updates in browser runtime
- [x] List wrappers update when backing signal arrays mutate
- [~] API ergonomics approach Solid JSX control-flow breadth for day-to-day app code
  - Improved with keyed/index helpers; typed case builders still pending

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
- `Solid.JSX`
- `Solid.Component`
- `Solid.DOM`
- `Solid.DOM.HTML`
- `Solid.DOM.SVG`
- `Solid.DOM.Events`
- `Solid.DOM.EventAdapters`
- `Solid.Control`

## How To Update This Plan

Whenever a task is implemented:

1. Mark the checkbox as done.
2. Add file paths that implemented the task.
3. Add test names or scenarios that verify behavior.
4. If API shape changed, update `DECISIONS.md` and this plan together.
