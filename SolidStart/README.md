# SolidStart in PureScript

This folder tracks the SolidStart wrapper direction for `purs-solid`.

## Main goal

Use PureScript as the app-authoring language for SolidStart-style apps, with parity focused on the latest Hacker News fixture from:

- `solidjs/solid-start` `main` -> `apps/fixtures/hackernews`

Runtime target for the example app is:

- `@solidjs/start` alpha + Nitro (Vite plugin flow)

## Source of truth

- PureScript app source: `src/Examples/SolidStart/`
- Route source: `src/Examples/SolidStart/Routes/**/*.purs`
- Generated app output: `examples/solid-start/`

`examples/solid-start/` is generated and should not be treated as hand-authored source.

## How generation works

- `npm run gen:routes` scans PureScript route files and generates `src/Solid/Start/Internal/Manifest.purs`.
- `npm run gen:example:solid-start-app` generates the SolidStart app folder in `examples/solid-start/`.
- Generated route wrappers are `.jsx` files that forward route path context into PureScript app rendering.

## Commands

```bash
npm run gen:routes
npm run gen:example:solid-start-app
npm run install:example:solid-start
npm run dev:example:solid-start
```

Note: the generated alpha app requires Node.js `>=22`.

Build production output for the generated app:

```bash
npm run build:example:solid-start
```

## Notes

- The example keeps app behavior in PureScript under `src/Examples/SolidStart`.
- Minimal JS/JSX glue exists for SolidStart runtime entrypoints and generated file-route wrappers.
- A separate Vinxi-based SSR runtime demo still exists at `src/Examples/SolidStartSSR/` for legacy/runtime experiments.
