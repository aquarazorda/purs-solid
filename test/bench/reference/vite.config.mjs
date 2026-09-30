import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import solid from "@solidjs/vite-plugin";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));

export default defineConfig({
  root: here("."),
  logLevel: "warn",
  plugins: [solid()],
  build: {
    outDir: here("../../../dist/bench-reference"),
    emptyOutDir: true,
    modulePreload: false,
    rollupOptions: {
      input: here("./rows.jsx"),
      output: { format: "iife", entryFileNames: "bench.js" },
    },
  },
});
