import { createApp } from "vinxi";

export default createApp({
  routers: [
    {
      name: "public",
      type: "static",
      dir: "./public",
      base: "/",
    },
    {
      name: "ssr",
      type: "http",
      base: "/",
      target: "server",
      handler: "./app/server.js",
    },
  ],
});
