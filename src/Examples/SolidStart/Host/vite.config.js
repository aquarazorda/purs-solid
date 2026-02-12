import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";

import { solidStart } from "@solidjs/start/config";

export default defineConfig({
  plugins: [solidStart()],
  resolve: {
    alias: {
      "#purs": fileURLToPath(new URL("../../output", import.meta.url)),
    },
  },
});
