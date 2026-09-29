import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import solid from "@solidjs/vite-plugin";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));

export default defineConfig({
  root: here("."),
  plugins: [
    solid({
      start: { app: "./app.js", node: true },
      ssr: true,
      // Without this, `"use server"` functions in PureScript FFI (`output/**/foreign.js`) ship to the browser.
      serverFunctions: {
        filter: { include: [here("../../../../output/**/foreign.js")] },
      },
    }),
  ],
  build: { outDir: here("./dist"), emptyOutDir: true },
});
