import { isServer, isServerFunction } from "@solidjs/web";

const untransformed = () =>
  Promise.reject(
    new Error(
      "purs-solid: this server function was not transformed by @solidjs/vite-plugin. " +
        "Add \"output/**/foreign.js\" to serverFunctions.filter.include in your Vite config."
    )
  );

export const checked = (fn) => (isServer || isServerFunction(fn) ? fn : untransformed);
