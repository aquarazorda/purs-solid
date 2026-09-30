import { query as solidQuery, revalidate } from "@solidjs/router";

export const queryImpl = (name, load) => solidQuery((argument) => load(argument)(), name);

export const queryServerImpl = (name, fn) => solidQuery(fn, name);

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
