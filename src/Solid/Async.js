import {
  createMemo,
  isPending as solidIsPending,
  latest as solidLatest,
  onCleanup,
  refresh as solidRefresh,
  resolve as solidResolve,
} from "solid-js";

const equalityOptions = (name, mode, equals) => {
  const options = {};
  if (name !== "") options.name = name;
  if (mode === "never") options.equals = false;
  else if (mode === "custom") options.equals = equals;
  return options;
};

// Each computation starts its Aff inside a Promise. The cleanup registered in
// the same computation runs when a newer computation supersedes it (or on
// disposal) and kills the fiber; a killed fiber's outcome is ignored.
export const createAsyncImpl = (start, name, mode, equals, compute) => {
  const value = createMemo(() => {
    const aff = compute();

    return new Promise((resolve, reject) => {
      let done = false;
      const cancel = start(aff)((result) => () => {
        if (!done) {
          done = true;
          resolve(result);
        }
      })((error) => () => {
        if (!done) {
          done = true;
          reject(error);
        }
      })();

      onCleanup(() => {
        if (!done) {
          done = true;
          cancel();
        }
      });
    });
  }, equalityOptions(name, mode, equals));

  return { value, refresh: value };
};

export const refreshImpl = (target) => {
  // Errors surface through the graph (loading/error boundaries), not here.
  solidRefresh(target).catch(() => {});
};

export const refreshPromiseImpl = (target) => solidRefresh(target);

export const isPending = (accessor) => () => solidIsPending(accessor);

export const latest = (accessor) => () => solidLatest(accessor);

export const resolveImpl = (accessor) => solidResolve(accessor);
