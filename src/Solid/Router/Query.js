import { query as solidQuery, revalidate } from "@solidjs/router";

export const queryImpl = (name, load) => solidQuery((argument) => load(argument)(), name);

export const queryServerImpl = (fn) => solidQuery(fn, fn.id);

export const runQueryImpl = (q, argument) => Promise.resolve(q(argument));

export const prefetchImpl = (q, argument) => {
  Promise.resolve(q(argument)).catch(() => {});
};

// Revalidation prefix-matches keys; the `[` keeps "user" from matching "userPosts".
export const queryKey = (q) => q.key + "[";

export const queryKeyForImpl = (q, argument) => q.keyFor(argument);

export const revalidateKeys = (keys) => () => {
  revalidate(keys);
};

export const revalidateAll = () => {
  revalidate();
};
