# SolidStart Routing Conventions (PureScript)

This document defines route file conventions for the PureScript SolidStart example.

## Route source root

- Route source files live under `src/Examples/SolidStart/Routes/`.
- Only `.purs` files are route sources.

## Naming rules

- Static segments must use lowercase names (`a-z`, `0-9`, `-`).
- Dynamic segment syntax:
  - `[id].purs` -> `:id`
  - `[...stories].purs` -> `*stories`
  - `[[lang]].purs` -> `:lang?`
- `index.purs` maps to an index segment (no extra URL segment).

Important folder/file rule:

- Use `stories/index.purs` for `/stories`.
- Use `stories/[id].purs` for `/stories/:id`.
- Do not try to use both `stories.purs` and `stories/[id].purs` in the same folder hierarchy.

## Current example mapping

- `src/Examples/SolidStart/Routes/[...stories].purs` -> `/*stories`
- `src/Examples/SolidStart/Routes/stories/[id].purs` -> `/stories/:id`
- `src/Examples/SolidStart/Routes/users/[id].purs` -> `/users/:id`

`/*stories` is intentionally used to model `/`, `/new`, `/show`, `/ask`, and `/job` like upstream Hacker News fixture behavior.

## Generated outputs

Run:

```bash
npm run gen:routes
npm run gen:example:solid-start-app
```

This generates:

- `src/Solid/Start/Internal/Manifest.purs` (typed route manifest)
- `examples/solid-start/src/routes/**/*.jsx` (Start file-route wrappers)

The route wrapper files are generated and should not be edited manually.
