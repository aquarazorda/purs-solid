import { query as solidQuery, revalidate } from "@solidjs/router";
import { isServer, isServerFunction } from "@solidjs/web";

export const queryImpl = (name, load) => solidQuery((argument) => load(argument)(), name);

// An untransformed server function must not run in the browser.
export const queryServerImpl = (name, fn) => {
  if (!isServer && !isServerFunction(fn)) {
    return solidQuery(
      () =>
        Promise.reject(
          new Error(
            "purs-solid: this server function was not transformed by @solidjs/vite-plugin. " +
              "Add \"output/**/foreign.js\" to serverFunctions.filter.include in your Vite config."
          )
        ),
      name
    );
  }
  return solidQuery(fn, name);
};

export const runQueryImpl = (q, argument) => Promise.resolve(q(argument));

// Revalidation prefix-matches keys; the `[` keeps "user" from matching "userPosts".
export const revalidateImpl = (q) => {
  revalidate(q.key + "[");
};

export const revalidateWithImpl = (q, argument) => {
  revalidate(q.keyFor(argument));
};

export const revalidateAll = () => {
  revalidate();
};
