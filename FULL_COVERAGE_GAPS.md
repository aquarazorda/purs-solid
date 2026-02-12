# Full Coverage Gaps (Solid + SolidStart)

This file tracks what is still missing for practical "full coverage" in `purs-solid`.

Definition used here:

- **Solid full coverage**: wrappers and behavior parity for Solid reference APIs we intend to support in PureScript.
- **SolidStart full coverage**: a usable Start-style full-stack flow (routing, server APIs, data/server functions, middleware/session/auth, metadata/prerender, SSR/hydration, DX).

## Current baseline

Already in place:

- Solid reactivity, control-flow components, context, store, utility wrappers, web render/hydrate wrappers.
- Advanced component semantics (`ErrorBoundary`, `Suspense`, `SuspenseList`, `NoHydration`, keyed variants).
- Non-component utility wrappers (`children`, `lazy`, `createUniqueId`, `catchError`, `from`, `mapArray`, `indexArray`, `mergeProps`, `splitProps`, `observable`, transitions).
- SolidStart foundations: route manifest generation, route matcher, server request/response models, middleware/session primitives, runtime adapters, routed example shell.

## Remaining for Solid full coverage

## 1) Rendering API parity

- [x] `renderToString`
- [x] `renderToStringAsync`
- [x] `renderToStream`
- [x] `hydrationScript`
- [ ] `DEV` exposure policy (if we choose to surface it)

Notes:

- We currently cover `render`, `hydrate`, and `isServer` in `Solid.Web`.
- SSR rendering wrappers are now exposed in `Solid.Web.SSR` to keep client/server concerns explicit.

## 2) JSX attribute/directive parity strategy

- [ ] Decide explicit support scope for directive-style attributes (`attr:*`, `bool:*`, `classList`, `prop:*`, `use:*`, etc.)
- [ ] Implement wrappers/adapters for chosen scope
- [ ] Add conformance tests for directive behavior

Notes:

- The docs include many JSX attribute directives; we should document which ones are first-class in PureScript and which are intentionally omitted.

## 3) Store utility parity

- [x] `produce`
- [x] `reconcile`
- [x] `modifyMutable` convenience wrapper (if aligned with our API style)

Notes:

- We already have `createStore`, `createMutable`, field/path operations, and unwrapping.

## 4) Server utility parity

- [ ] `getRequestEvent` equivalent policy for core Solid API surface

Notes:

- We have Start-specific request-event modeling; this item is about docs/reference parity expectations.

## Remaining for SolidStart full coverage

## 1) Entry + SSR/hydration completion

- [x] End-to-end SSR shell flow through `Solid.Start.Entry.Server` + `Solid.Start.Entry.Client`
- [x] Hydration success smoke (SSR output hydrated without mismatch)
- [x] Real runtime `Request/Response` interop path completed and documented

Notes:

- `Solid.Start.Entry.Server` now includes SSR response helpers that render app HTML, emit hydration scripts, and produce full HTML responses.
- `Solid.Start.Entry.Client` now includes `bootstrapAtId` so hydration targets the same SSR mount (`#app`) emitted by server entry helpers.
- Dedicated smoke coverage now validates hydration success through SSR HTML + client entry bootstrap: `npm run test:start-ssr-hydration-smoke`.
- `Solid.Start.Server.Runtime` now supports native web `Request` input parsing (method/path/query/headers/body) and native web `Response` output interop through runtime response adapters.

## 2) Data and server functions

- [x] Client call transport for `Solid.Start.Server.Function`
- [x] Cache key model + invalidation/revalidation hooks
- [x] Full error mapping coverage to `StartError` variants in integrated flows

Notes:

- `Solid.Start.Server.Function` now includes cache-key primitives (`cacheKeyFor`) plus invalidate/revalidate hooks in `callWithTransportCached` and `callWithTransportCachedAff`.
- HTTP transport can map typed Start errors through `START_ERROR:<Kind>:<message>` wire format (`encodeStartErrorWire`, `decodeStartErrorWire`) and `httpPostTransport` decoding.

## 3) API route completion

- [x] Streaming response support
- [x] More status-safe constructors/helpers
- [x] Route registration integrated into full app entry path (not isolated tests only)

Notes:

- `Solid.Start.Server.Response` now includes stream responses (`StreamBody`, `streamText`, `okStreamText`) and status-safe helpers (`okText`, `createdJson`, `noContent`, `badRequestText`, `notFoundText`, etc.).
- `Solid.Start.Server.Runtime` now preserves stream chunk metadata (`runtimeResponseStreamChunks`) and maps stream responses to runtime `Response` values.
- `Examples.StartSSRSmoke.ServerMain` now wires API route registration (`/api/health`, `/api/stream`, `/api/server-function`) into the same server entry handler used for SSR document responses.

## 4) Middleware/session/auth hardening

- [x] CSRF primitives
- [x] Cookie-backed session adapter (in addition to in-memory)
- [x] Auth identity propagation and hooks
- [x] Security-focused tests for middleware/session/auth flows

Notes:

- `Solid.Start.Middleware` now includes method-aware CSRF checks (`requireCsrfToken`) and identity middleware hooks (`requireIdentity`, `defaultAuthHooks`).
- `Solid.Start.Session` now includes a cookie adapter (`createCookieSessionAdapter`) plus token serialization helpers (`encodeSessionToken`, `decodeSessionToken`).
- Request helpers now support cookie/header security flows (`lookupCookie`, `withHeader`) and are covered by Start server/middleware/session tests.

## 5) Metadata/assets/prerender completion

- [ ] Static export pipeline hooks
- [ ] Metadata integration with SSR output/head emission
- [ ] Prerender manifest integration with route/app pipeline

## 6) Developer experience parity

- [ ] Starter template promotion from scaffold to production-ready baseline
- [ ] CLI scaffolding polish (config options, validation, docs)
- [ ] Command flow comparable to a standard Start bootstrap/deploy workflow

## 7) Example app parity upgrades

- [ ] Move from static multi-entry HTML shells toward a more unified Start-style route serving model
- [x] Add API-backed route/demo in `examples/solid-start`
- [x] Add server-function demo route in `examples/solid-start`

## Cross-cutting gaps

- [x] Write and maintain a machine-checkable API coverage matrix (docs item -> module/function/test)
- [ ] Expand smoke coverage: navigation + SSR/hydration + API + server functions in one flow
- [ ] Performance and memory regression checks for long-lived reactive usage

Notes:

- Matrix source: `API_COVERAGE_MATRIX.json`
- Validation command: `npm run check:coverage-matrix`

## Recommended execution order

1. SSR rendering wrappers + hydration smoke.
2. Integrated server function transport and error mapping.
3. Cookie session + CSRF + auth hooks.
4. Metadata/prerender export integration.
5. Coverage matrix + docs hardening.

## Verification commands

Use pnpm commands as default:

```bash
pnpm run gen:routes
pnpm run build:example:solid-start
pnpm run test:start
pnpm run test:purescript
```
