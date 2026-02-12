# Examples

Examples in this folder:

- `todomvc/` - TodoMVC application UI and styling.
- `counter/` - signal/memo counter UI and styling.
- `solid-start/` - generated SolidStart alpha Hacker News app.

`examples/solid-start/` is generated from `src/Examples/SolidStart/` via `npm run gen:example:solid-start-app`.

For SolidStart generation and routing manifest, run:

```bash
npm run gen:example:solid-start-app
npm run gen:routes
```

PureScript entry modules live in `src/Examples/*`.

Build commands:

```bash
npm run build:examples
```

Run the SolidStart alpha app:

```bash
npm run install:example:solid-start
npm run dev:example:solid-start
```

Serve from repo root:

```bash
npm run serve:examples
```

Open `http://localhost:4173/examples/`.
