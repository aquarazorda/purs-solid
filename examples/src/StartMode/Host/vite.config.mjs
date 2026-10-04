import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import solid from "purs-solid/vite";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));

export default defineConfig({
  root: here("."),
  plugins: [
    solid({
      start: { app: "Examples.StartMode.App", middleware: "Examples.StartMode.Middleware", node: true },
      ssr: true,
      compileViews: process.env.PURS_SOLID_COMPILE_VIEWS === "1",
    }),
  ],
  build: { outDir: here("./dist"), emptyOutDir: true },
});
