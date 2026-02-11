# Examples

Each example has its own static shell and styles:

- `todomvc/` - TodoMVC application UI and styling.
- `counter/` - signal/memo counter UI and styling.
- `solid-start/` - SolidStart-style routed app shell with `counter` and `todomvc` routes.

For the SolidStart scaffold route manifest, run:

```bash
npm run gen:routes
npm run test:start
```

PureScript entry modules live in `src/Examples/*`.

Build commands:

```bash
npm run build:examples
```

Serve from repo root:

```bash
npm run serve:examples
```

Open `http://localhost:4173/examples/`.
