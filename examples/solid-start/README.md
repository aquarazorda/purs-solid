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
- Counter and TodoMVC are loaded on route pages via embedded example views.

## Helpful commands

```bash
npm run gen:routes
npm run test:start
```
