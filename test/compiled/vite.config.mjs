import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import { pursViews } from "../../vite/compile.mjs";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));
const compiled = process.env.PURS_SOLID_VIEWS === "compiled";

export default defineConfig({
  root: here("."),
  logLevel: "warn",
  plugins: compiled ? [pursViews()] : [],
  resolve: { conditions: ["browser", "development"] },
  define: { "process.env.NODE_ENV": JSON.stringify("development") },
  build: {
    outDir: here(`../../dist/compiled-${compiled ? "compiled" : "runtime"}`),
    emptyOutDir: true,
    minify: false,
    modulePreload: false,
    rollupOptions: {
      input: here("./entry.js"),
      output: { format: "iife", entryFileNames: "app.js" },
    },
  },
});
