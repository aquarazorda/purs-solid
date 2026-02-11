# SolidStart in PureScript

This folder tracks the SolidStart implementation effort for `purs-solid`.

## Current status

- Manifest generation for file-based routes is scaffolded.
- Route matching runtime supports static/param/optional/catch-all segments with precedence behavior.
- Route fixtures are scaffolded under `examples/solid-start/src/routes/` to exercise generation and matching.
- `Examples.SolidStart` now renders `/`, `/counter`, and `/todomvc` from one routed PureScript entrypoint with client-side route transitions (without iframe embedding).
- App and entrypoint skeletons are available under `src/Solid/Start/App.purs` and `src/Solid/Start/Entry/*`.
- Typed server request/response primitives now exist under `src/Solid/Start/Server/*`.
- Typed server-function serialization scaffolding exists under `src/Solid/Start/Server/Function.purs` and `src/Solid/Start/Internal/Serialization.purs`.
- Middleware composition primitives exist in `src/Solid/Start/Middleware.purs`.
- Request-local context helpers exist in `src/Solid/Start/Request/Event.purs`.
- Session store primitives exist in `src/Solid/Start/Session.purs`.
- Metadata, asset URL, and prerender-plan primitives exist in `src/Solid/Start/Meta.purs`, `src/Solid/Start/StaticAssets.purs`, and `src/Solid/Start/Prerender.purs`.
- Runtime request/response adapter primitives exist in `src/Solid/Start/Server/Runtime.purs`.
- Client navigation interop primitives exist in `src/Solid/Start/Client/Navigation.purs`.
- Entry points and server/API modules are still early; runtime integration, CSRF/auth, and full session strategy are pending.

## Docs in this folder

- `SolidStart/IMPLEMENTATION_PLAN.md` - staged roadmap and milestones.
- `SolidStart/ROUTING_CONVENTIONS.md` - route file conventions and generation workflow.

## Commands

```bash
npm run gen:routes
spago test
npm run test:start
```

`gen:routes` scans `examples/solid-start/src/routes/**/*.purs` and regenerates `src/Solid/Start/Internal/Manifest.purs`.

To preview the static example page:

```bash
npm run serve:examples
```

Then open `http://localhost:4173/examples/solid-start/`.

To scaffold a new copy from the in-repo example template:

```bash
npm run create:start-app -- my-start-app
```
