# SolidStart SSR Example (Vinxi + PureScript)

This example runs as a standalone Vinxi app at the web root (`/`).

The server and client behavior comes from PureScript modules in this folder (`Examples.SolidStartSSR.*`).
Vinxi is used as the runtime host.

## Run

```bash
npm install
npm run dev
```

Then open `http://localhost:3000/`.

## Build and start

```bash
npm run build
npm run start
```

## Routes

- `/`
- `/stream/`
- `/server-function/`
- `/api/health`
- `/api/stream`
- `/api/server-function`
