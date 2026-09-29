import { isServer, isServerFunction } from "@solidjs/web";

// An untransformed server function's body was bundled; don't run it in the browser.
export const callImpl = (fn, argument) => {
  if (!isServer && !isServerFunction(fn)) {
    return Promise.reject(
      new Error(
        "purs-solid: this server function was not transformed by @solidjs/vite-plugin. " +
          "Add \"output/**/foreign.js\" to serverFunctions.filter.include in your Vite config."
      )
    );
  }
  return Promise.resolve(fn(argument));
};
