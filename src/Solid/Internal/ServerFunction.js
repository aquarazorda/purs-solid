import { isServer, isServerFunction } from "@solidjs/web";

const untransformed = () =>
  Promise.reject(
    new Error(
      "purs-solid: this server function was not compiled for the browser. " +
        "Re-export `useServer` from its module and build with purs-solid/vite."
    )
  );

export const checked = (fn) => (isServer || isServerFunction(fn) ? fn : untransformed);
