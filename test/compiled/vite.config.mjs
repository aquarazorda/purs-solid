import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import { pursViews } from "../../vite/compile.mjs";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));
// PURS_SOLID_VIEWS: runtime | compiled. PURS_SOLID_TARGET: client | hydrate | server.
// PURS_SOLID_OUTPUT: output (purs) | output-es (purs-backend-es).
const mode = process.env.PURS_SOLID_VIEWS;
const target = process.env.PURS_SOLID_TARGET;
const output = process.env.PURS_SOLID_OUTPUT;
const server = target === "server";
const views = server ? { generate: "ssr", hydratable: true } : { generate: "dom", hydratable: target === "hydrate" };

export default defineConfig({
  root: here("."),
  logLevel: "warn",
  plugins: mode === "compiled" ? [pursViews(views)] : [],
  resolve: {
    alias: { "@fixture": here(`../../${output}/Test.Compiled.Fixture/index.js`) },
    ...(server ? {} : { conditions: ["browser", "development"] }),
  },
  define: server ? {} : { "process.env.NODE_ENV": JSON.stringify("development") },
  build: {
    outDir: here(`../../dist/compiled/${output}/${mode}-${target}`),
    emptyOutDir: true,
    minify: false,
    modulePreload: false,
    ssr: server ? here("./server.js") : undefined,
    rollupOptions: server
      ? { output: { format: "es", entryFileNames: "server.js" } }
      : { input: here(`./${target}.js`), output: { format: "es", entryFileNames: "app.js", codeSplitting: false } },
  },
});
