import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import { pursViews } from "../../../vite/compile.mjs";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));

export default defineConfig({
  root: here("."),
  logLevel: "warn",
  plugins: [pursViews()],
  resolve: { conditions: ["browser", "production"] },
  build: {
    outDir: here("../../../dist/bench-compiled"),
    emptyOutDir: true,
    modulePreload: false,
    rollupOptions: {
      input: here("./entry.js"),
      output: { format: "iife", entryFileNames: "bench.js" },
    },
  },
});
