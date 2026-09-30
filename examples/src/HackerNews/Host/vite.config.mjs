import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import solid from "purs-solid/vite";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));

export default defineConfig({
  root: here("."),
  plugins: [solid({ start: { app: "Examples.HackerNews.App", node: true }, ssr: true })],
  build: { outDir: here("./dist"), emptyOutDir: true },
});
