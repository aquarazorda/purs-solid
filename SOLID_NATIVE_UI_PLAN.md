# Solid-Native UI Authoring Plan

This plan describes how to build a Solid-native UI layer for PureScript with developer experience comparable to `purescript-react-basic`, while staying fully aligned with Solid semantics.

## Objective

Build a first-class UI authoring surface on top of current `purs-solid` primitives so developers can:

- define components ergonomically
- compose HTML/SVG views with strong types
- handle events and context safely
- render/hydrate in browser with predictable behavior

without introducing React concepts or hook emulation.

## Principles

1. Solid-native mental model only
   - signals, memos, effects, owner/lifecycle, control-flow primitives
   - no React terminology (`useState`, `useEffect`, VDOM hook lifecycle)
2. Functional API boundaries
   - recoverable failures as values (`Either` / `Maybe`), not throws
3. Great DX by default
   - concise constructors, strong inference, generated DOM coverage, clear docs
4. Pre-1.0 correctness over compatibility
   - direct rewrites are allowed when API can be made more principled

## Current Base (already implemented)

- Core runtime: `Solid.Signal`, `Solid.Reactivity`, `Solid.Root`, `Solid.Utility`, `Solid.Lifecycle`
- Async/state/runtime: `Solid.Resource`, `Solid.Context`, `Solid.Store`, `Solid.Web`
- Node + browser smoke testing foundations are in place

## What We Need To Add

## 1) View Core (Solid-native replacement for `React.Basic`)

Create a new component/view layer:

- `Solid.JSX`
  - opaque `JSX` type
  - `empty`, `fragment`, `text`, `keyed`
- `Solid.Component`
  - component type and constructors
  - `element` helpers for applying props and children

Recommended setup-oriented component shape:

```purescript
type Component props = props -> Effect JSX
```

This matches Solid's setup semantics and works naturally with existing effectful primitives (`createSignal`, `createEffect`, etc.).

## 2) DOM Authoring Layer (Solid-native replacement for `React.Basic.DOM`)

Create ergonomic, typed DOM constructors:

- `Solid.DOM.HTML`
- `Solid.DOM.SVG`
- `Solid.DOM.Internal` (shared internals)
- `Solid.DOM.Events`

DX requirements:

- typed prop records
- event handler helpers
- concise constructor variants (`div`, `div_`, etc.)
- `css` style helper and merge combinator
- `data-*` / `aria-*` support

Implementation note: generate large HTML/SVG constructor modules instead of writing by hand.

## 3) Control Flow Components (Solid-native, not React-like)

Expose Solid control-flow primitives as PureScript modules:

- `Solid.Control.Show`
- `Solid.Control.For`
- `Solid.Control.Index`
- `Solid.Control.Switch`
- `Solid.Control.Dynamic`
- optional: `Solid.Control.Portal`

This is essential for idiomatic Solid UI authoring and list rendering performance.

## 4) Browser Mounting API Refinement

Refine current `Solid.Web` for UI-layer integration:

- keep safe `Either`-based render/hydrate behavior
- ensure JSX-facing entrypoints are first-class
- add client-root handle APIs if needed:
  - `createRoot`
  - `renderRoot`
  - `unmountRoot`

Also add SSR-hydrate success tests (not only non-SSR behavior checks).

## 5) Context for JSX Trees

Current context primitives are owner-based and low-level. Add JSX-facing provider/consumer ergonomics:

- context provider component helpers
- context consumer helpers for component trees
- preserve explicit missing-provider behavior in types/docs

## 6) Store + Resource UI Ergonomics

Add convenience APIs specifically for view code:

- selector-style store helpers for fine-grained subscriptions
- resource view helpers (`loading`, `error`, `latest` access patterns)
- optional adapters for common async UI states

## Changes Needed Because We Use Signals and Effects

To stay Solid-native and keep DX high, we should make these explicit:

1. Component setup model, not hook model
   - component initialization is effectful and runs once per instance
   - signals/effects are created inside setup
2. Encourage explicit dataflow
   - local state: `createSignal`
   - derivations: `createMemo` / selectors
   - side effects: `createEffect` + `onCleanup`
3. Avoid synthetic hook wrappers
   - do not add React-style `useState`/`useEffect` shims
4. Keep handler ergonomics high
   - event helpers should avoid boilerplate while keeping strong typing
5. Keep failure modes explicit
   - render/hydrate/mount lookup and resource reads stay value-encoded

## Milestones

### M8: JSX + Component Core

- Add `Solid.JSX` and `Solid.Component`
- Add core helpers (`empty`, `fragment`, `text`, `keyed`, `element`)
- Acceptance: define and render a small component tree in browser smoke tests

### M9: Typed DOM Layer

- Add generated HTML/SVG constructors and event module
- Add style and aria/data support
- Acceptance: build a form/list UI without unsafe casts in user code

### M10: Control Flow

- Add `Show`, `For`, `Index`, `Switch`, `Dynamic` wrappers
- Acceptance: list diffing/toggling tests pass in browser

### M11: Client/SSR Integration

- Finalize root render/hydrate/unmount APIs for JSX layer
- Add SSR-backed hydrate success smoke test
- Acceptance: server markup hydrates successfully in browser test

### M12: DX Hardening

- Add docs and examples for all UI modules
- Add simplified import surface (`Solid.DOM.Simplified` style module)
- Add compile-time and runtime diagnostics for common mistakes
- Acceptance: tutorial app can be written without touching internals

## Test Strategy

1. PureScript unit tests for API contracts and type-level behavior
2. Browser smoke tests (already present) expanded to:
   - control flow
   - event handling
   - mount/unmount behavior
   - hydrate success with SSR markup
3. Coverage matrix against upstream Solid tests for wrapped features

## DX Guardrails (must-have)

- zero user-facing `unsafeCoerce`
- short, discoverable module names
- predictable constructor naming (`div`, `div_`, etc.)
- practical examples for common patterns (forms, lists, async state)
- good defaults before advanced options

## Open Design Decisions

1. DOM prop API style
   - record props only
   - or record + attribute builders
2. Generated code source
   - derive from Solid/dom-expressions metadata
   - or maintain custom schema in repo
3. Package layout
   - single package for now
   - optional split later (`core`, `dom`, `control`)

## Recommended Immediate Start

1. Implement M8 (`Solid.JSX`, `Solid.Component`) with one end-to-end browser test.
2. Implement M9 minimal DOM subset first (`div`, `span`, `button`, `input`, `form`, `ul`, `li`) before full generation.
3. Add M10 `Show` + `For` early, then complete full control-flow set.
