# SolidStart Routing Conventions (PureScript)

This document defines how file-based routing works for PureScript route files.

## Route Root

- Route files for the SolidStart example app live under `examples/solid-start/src/routes/`.
- Only `.purs` files are treated as route sources.

## File Name to URL Mapping

Use these segment conventions in file and folder names:

- `index.purs` -> index segment (no path part)
- `about.purs` -> `/about`
- `[slug].purs` -> `/:slug`
- `[...parts].purs` -> `/*parts`
- `[[lang]].purs` -> `/:lang?`

Examples:

- `examples/solid-start/src/routes/index.purs` -> `/`
- `examples/solid-start/src/routes/about.purs` -> `/about`
- `examples/solid-start/src/routes/blog/[slug].purs` -> `/blog/:slug`
- `examples/solid-start/src/routes/docs/[...parts].purs` -> `/docs/*parts`
- `examples/solid-start/src/routes/[[lang]]/about.purs` -> `/:lang?/about`

## Module Names

PureScript module names still follow normal PureScript rules.

- File path syntax (like `[slug]`) is route metadata.
- The generator reads `module ... where` from file content.
- Route matching uses the file path, not the module name.

## Generated Manifest

Run:

```bash
npm run gen:routes
```

The command generates:

- `src/Solid/Start/Internal/Manifest.purs`

Generator options:

- `--routes-root <path>` to override route source root
- `--output <path>` to override generated manifest file path

Route diagnostics:

- generator reports equivalent dynamic-shape conflicts
- generator reports optional/catch-all overlap warnings with file-path guidance

The generated module contains `allRoutes :: Array RouteDef`, which is consumed by routing runtime code.

## Current Status

- Manifest generation is available.
- Runtime matcher supports static, param, optional, and catch-all segments.
- Matcher strips query/fragment and ignores trailing slashes for segment matching.
- Route precedence favors more specific matches (static > param > optional > catch-all).
