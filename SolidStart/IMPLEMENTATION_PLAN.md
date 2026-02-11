# SolidStart Functional Implementation Plan (PureScript)

This document defines how `purs-solid` can grow from a Solid runtime wrapper into a SolidStart-capable full-stack framework surface using purely functional PureScript APIs.

Scope is based on SolidStart docs, beginning with:

- https://docs.solidjs.com/solid-start/getting-started

Related sections that define required functionality:

- routing
- API routes
- data fetching and mutation
- middleware, sessions, auth
- metadata, static assets, route pre-rendering

## Goal

Provide a SolidStart-style developer experience in PureScript with:

- typed route definitions and params
- typed server/client entry points
- SSR + hydration compatibility
- API handlers with explicit request/response/error types
- no throw-based public API; use `Either`/`Maybe` and domain errors

## Functional Design Constraints

- All side effects live in `Effect`/`Aff`.
- Public wrappers expose recoverable errors as `Either StartError a`.
- Optional values use `Maybe` only for expected absence.
- No hidden mutable global state in PureScript APIs.
- FFI surface remains small and isolated under `src/Solid/Start/*.js`.

## Baseline From SolidStart Getting Started

SolidStart projects are scaffolded around:

```text
public/
src/
  routes/
    index.tsx
  entry-client.tsx
  entry-server.tsx
  app.tsx
```

We should provide PureScript equivalents of this structure and behavior.

## Proposed PureScript Module Layout

Core namespace:

- `Solid.Start.App`
- `Solid.Start.Entry.Client`
- `Solid.Start.Entry.Server`
- `Solid.Start.Routing`
- `Solid.Start.Route.Pattern`
- `Solid.Start.Route.Params`
- `Solid.Start.Server.Function`
- `Solid.Start.Server.API`
- `Solid.Start.Server.Response`
- `Solid.Start.Server.Request`
- `Solid.Start.Middleware`
- `Solid.Start.Session`
- `Solid.Start.Meta`
- `Solid.Start.Prefetch`
- `Solid.Start.Prerender`
- `Solid.Start.StaticAssets`

Support namespace:

- `Solid.Start.Error`
- `Solid.Start.Internal.Manifest` (generated)
- `Solid.Start.Internal.Serialization`

## Milestones

Tracking:

- `[x]` done
- `[~]` in progress
- `[ ]` not started

### M0 - Project Bootstrap in this repository

- [x] Create `SolidStart/` planning folder
- [x] Add this implementation plan
- [x] Add `SolidStart/README.md` with status and links
- [x] Add `src/Solid/Start` module tree skeleton
  - Added: `Solid.Start.Routing`, `Solid.Start.Routing.Manifest`, `Solid.Start.Route.Pattern`, `Solid.Start.Route.Params`, `Solid.Start.Internal.Manifest`
- [x] Add `test/Test/Start` test tree skeleton
  - Added: `test/Test/Start/Routing.purs` and runner wiring in `test/Test/Main.purs`

Acceptance:

- [x] Folder and module scaffolding exists and compiles
- [x] Plan + decision links are discoverable from root `README.md`

### M1 - Entry Points and App Shell

Goal: map `app.tsx`, `entry-client.tsx`, `entry-server.tsx` to typed PureScript APIs.

Tasks:

- [x] Define `App` abstraction in `Solid.Start.App`
  - Added `App`, `createApp`, and `runApp` in `src/Solid/Start/App.purs`
- [~] Implement client bootstrap wrapper (`hydrate`/`render` orchestration)
  - Added `bootstrapAt` and `bootstrapInBody` in `src/Solid/Start/Entry/Client.purs`
- [~] Implement server entry wrapper for request handling
  - Added typed request/response-backed handler model in `src/Solid/Start/Entry/Server.purs`
- [x] Define typed `StartConfig` (base path, asset prefix, dev/prod flags)
  - Added `StartConfig` and `defaultStartConfig` in `src/Solid/Start/App.purs`
- [ ] Add browser smoke test: server-rendered shell hydrates without mismatch

Acceptance:

- [ ] Minimal app shell runs through client + server entry wrappers
- [x] Hydration errors are typed and surfaced to caller

### M2 - File-Based Routing and Route Manifest

Goal: functional equivalent of SolidStart `src/routes` behavior (scaffolded in `examples/solid-start/src/routes`).

Tasks:

- [x] Design route segment ADT (static, param, catch-all, optional)
  - Implemented in `src/Solid/Start/Route/Pattern.purs`
- [x] Build a manifest format for discovered routes
  - Implemented generated `RouteDef` manifest in `src/Solid/Start/Internal/Manifest.purs`
- [x] Add route matching with typed params decode
  - Implemented matcher and typed params in `src/Solid/Start/Routing.purs` and `src/Solid/Start/Route/Params.purs`
- [x] Add route ranking/precedence tests
  - Added precedence and decoding cases in `test/Test/Start/Routing.purs`
- [x] Create a generator script for route manifest from filesystem
  - Implemented `scripts/gen-routes.mjs` + `npm run gen:routes`

Acceptance:

- [x] Route matching is deterministic and covered by tests
- [x] Params decode to typed records (or typed lookup API)
  - Implemented typed lookup/decode helpers in `src/Solid/Start/Route/Params.purs`

### M3 - Data Fetching and Server Functions

Goal: SolidStart-style server data APIs with PureScript type safety.

Tasks:

- [~] Add `ServerFunction input output` abstraction
  - Added `Solid.Start.Server.Function` with typed `call` and `dispatchSerialized`
- [~] Add serialization boundary with explicit codec requirements
  - Added `WireCodec` in `Solid.Start.Internal.Serialization`
- [~] Implement client call wrapper and server dispatcher
  - Added serialized dispatcher path in `dispatchSerialized`
- [ ] Add typed cache key model and invalidation hooks
- [x] Add tests for happy path, decode failure, and server exception mapping
  - Added `test/Test/Start/ServerFunction.purs`

Acceptance:

- [~] Server functions callable from client with typed input/output
- [ ] Failures are mapped to `StartError` variants without uncaught throws

### M4 - API Routes and Responses

Goal: equivalent to SolidStart API routes and response helpers.

Tasks:

- [x] Define typed request model (`method`, `headers`, `query`, `body`)
  - Added `Solid.Start.Server.Request` with typed method/header/query/body accessors
  - Added runtime adapter scaffold in `Solid.Start.Server.Runtime`
- [~] Define response constructors (json, text, html, redirect, stream)
  - Added `text`, `json`, `html`, `redirect`, `methodNotAllowed` in `Solid.Start.Server.Response`
- [~] Add status-code-safe helpers
  - Added typed helpers for common status flows (`methodNotAllowed`, constructor APIs)
- [x] Add route-level API handler registration
  - Added `Solid.Start.Server.Router` with `registerRoutes`, `appendRoute`, and `dispatch`
- [~] Add integration tests for JSON and redirect responses
  - Added server API module tests in `test/Test/Start/Server.purs`
  - Added router dispatch tests in `test/Test/Start/Router.purs`

Acceptance:

- [x] API handlers can be authored in PureScript only
- [~] Common response shapes require no raw JS interop

### M5 - Middleware, Sessions, and Auth Foundations

Goal: foundation for advanced SolidStart features.

Tasks:

- [~] Implement middleware pipeline as typed function composition
  - Added `Solid.Start.Middleware` with composable `run` pipeline
- [~] Add request-local context propagation
  - Added `Solid.Start.Request.Event` with typed context attach/read helpers
- [~] Define session store interface (cookie + pluggable backend)
  - Added `Solid.Start.Session` and in-memory `SessionStore` interface implementation
- [ ] Add CSRF/session security primitives
- [ ] Add minimal auth hook points (identity in request context)

Acceptance:

- [x] Middleware order and short-circuit behavior are tested
  - Added middleware tests in `test/Test/Start/Middleware.purs`
- [x] Session read/write is typed and effectful only
  - Added session store tests in `test/Test/Start/Session.purs`

### M6 - Metadata, Assets, and Pre-render

Goal: parity for metadata and static output workflows.

Tasks:

- [~] Add document metadata model (title/meta/link/script)
  - Added `Solid.Start.Meta` with typed head tag model
- [~] Add static asset URL resolver with base-path awareness
  - Added `Solid.Start.StaticAssets` URL resolvers
- [~] Add route pre-render list generation API
  - Added `Solid.Start.Prerender` plan helpers
- [ ] Add static export pipeline hooks
- [~] Add tests for generated head tags and pre-render manifests
  - Added coverage in `test/Test/Start/MetaAssets.purs`

Acceptance:

- [x] Metadata composition is deterministic
- [x] Pre-render outputs are reproducible from pure inputs

### M7 - Developer Experience and Template

Goal: make this usable as a starter flow similar to `npm init solid@latest`.

Tasks:

- [~] Add starter template folder with PureScript entry files
  - Added scaffold at `examples/solid-start/src/*`
- [x] Add setup CLI script for scaffolding local app skeleton
  - Added `scripts/create-solid-start-app.mjs` and `npm run create:start-app`
- [~] Document build/dev commands and expected structure
  - Added docs in `SolidStart/README.md`, `SolidStart/ROUTING_CONVENTIONS.md`, and `examples/solid-start/README.md`
- [~] Add end-to-end smoke app that exercises routing + API + hydration
  - Added Start server/browser smoke scripts: `test/start/run-server-smoke.mjs`, `test/start/run-browser-smoke.mjs`

Acceptance:

- [~] New app can be scaffolded and run with documented commands
- [~] Starter passes `spago test` + browser smoke + server smoke

## Runtime Integration Notes

SolidStart currently relies on Vinxi (Vite for dev and Nitro for production runtime).

For this repository, we should phase integration in this order:

1. Implement PureScript runtime contracts first.
2. Keep JS bridge minimal for dev server/runtime integration.
3. Introduce Vinxi/Nitro coupling only where unavoidable.
4. Preserve the option to support alternative runtimes later.

## Error Model (Initial Draft)

Proposed top-level error ADT:

- `RouteNotFound`
- `RouteDecodeError`
- `ServerFunctionDecodeError`
- `ServerFunctionExecutionError`
- `SerializationError`
- `MiddlewareError`
- `SessionError`
- `HydrationError`
- `EnvironmentError`

All modules should map internal/FFI failures into these (or subdomain) variants.

## Test Strategy

- Unit tests for routing, params, codecs, and response constructors.
- Integration tests for server function dispatch and API handlers.
- Browser smoke tests for hydration and navigation.
- Server smoke tests for middleware/session behavior.

Suggested commands to add once modules exist:

- `spago test`
- `npm run test:start-browser-smoke`
- `npm run test:start-server-smoke`

## Immediate Next Implementation Steps

1. Refine route diagnostics to reduce noisy optional-overlap warnings and classify severity.
2. Add request/response adapter layer from real runtime web `Request/Response` objects into typed Start request/response.
3. Add browser smoke for client bootstrap once SSR shell entry exists.
4. Add CSRF/auth/session integration flows on top of middleware + request context.
5. Update root `IMPLEMENTATION_PLAN.md` and `DECISIONS.md` as Start APIs stabilize.

---

This plan is intentionally staged so we can start with typed functional contracts and grow toward full SolidStart behavior without overcommitting to JS runtime details too early.
