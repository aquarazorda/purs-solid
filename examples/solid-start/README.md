# SolidStart Example (Scaffold)

This folder contains the in-repo SolidStart-style app scaffold for the `purs-solid` Start effort.

## Layout

```text
examples/solid-start/
  counter/
    index.html
  todomvc/
    index.html
  src/
    app.purs
    entry-client.purs
    entry-server.purs
    routes/
      index.purs
      counter.purs
      todomvc.purs
```

## Notes

- This app demonstrates route navigation between `/`, `/counter`, and `/todomvc`.
- Route files are used by `npm run gen:routes` to generate the routing manifest consumed by `Solid.Start.Routing.Manifest`.
- A single PureScript app entry (`Examples.SolidStart`) resolves the current route and renders Counter or TodoMVC directly (no iframe embedding).
- Route transitions use client-side `pushState` navigation with `popstate` handling for back/forward support.
- Example code stays in PureScript only; browser interop lives in `Solid.Start.Client.Navigation`.

## Helpful commands

```bash
npm run gen:routes
npm run test:start
```
