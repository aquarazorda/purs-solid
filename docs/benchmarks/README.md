# Benchmarks

The rows benchmark (modelled on the keyed [js-framework-benchmark](https://github.com/krausest/js-framework-benchmark)), comparing purs-solid with the same app written directly in Solid 2 JSX. Results: `purs-solid.json` and `reference.json`.

| Operation | plain Solid 2 | purs-solid | ratio |
|---|---|---|---|
| create 1k rows | 11.9 ms | 19.8 ms | 1.66x |
| replace 1k rows | 13.4 ms | 21.0 ms | 1.57x |
| append 1k rows | 13.1 ms | 20.6 ms | 1.57x |
| create 10k rows | 127.8 ms | 214.5 ms | 1.68x |
| update every 10th row | 2.8 ms | 3.3 ms | 1.20x |
| swap rows | 1.0 ms | 1.4 ms | 1.35x |
| select row | 0.3 ms | 0.2 ms | ≈ |
| clear 1k rows | 1.6 ms | 2.6 ms | 1.63x |

| Bundle | minified | gzip | brotli |
|---|---|---|---|
| plain Solid 2 (Vite) | 66.0 kB | 24.0 kB | 21.7 kB |
| purs-solid (`spago bundle`) | 99.6 kB | 35.0 kB | 31.5 kB |

Updates cost about the same in both. Creating DOM is about 1.6x slower, because PureScript can't use Solid's JSX compiler: purs-solid creates each element through Solid's public `dynamic()` and `spread`, while compiled Solid clones one template per row. Most of the bundle is Solid's own runtime (`@solidjs/signals` 61 kB and `@solidjs/web` 17 kB minified). purs-solid itself is about 8 kB, and the PureScript libraries it uses about 10 kB.

## Method

- **Timing:** each operation is timed from the click until Solid's updates have flushed and layout is forced.
- **Samples:** 3 warm-up and 10 measured samples per operation (1 and 5 for 10k rows), over 3 runs on fresh pages. Each result is the median of the run medians.
- **Environment:** headless Chromium 145, Apple M4 Pro, Node 22.17, Solid `2.0.0-rc.11`.
- **Apps:** `examples/src/Bench/Rows.purs` and its plain-Solid twin `test/bench/reference/rows.jsx` use the same data, markup and update strategy: a signal per row label, a keyed list, and a projection-based selector.

```bash
npm run bench -- --runs=3
```

```bash
npm run bench:reference -- --runs=3
```
