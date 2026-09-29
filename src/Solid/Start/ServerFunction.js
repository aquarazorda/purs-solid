import { isServer, isServerFunction } from "@solidjs/web";

// On the client a server function must have been replaced by the plugin's
// RPC reference; otherwise its body was bundled and would run in the browser.
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
