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
// Each computation starts its Aff inside a Promise. The cleanup registered in
// the same computation runs when a newer computation supersedes it (or on
// disposal) and kills the fiber; a killed fiber's outcome is ignored.
//
// With a codec, the memo holds the *encoded* value (that's what Solid
// serializes into the page), and a second memo decodes it once per change.
export const createAsyncImpl = (start, rep, mode, equals, compute) => {
  const encode = rep.encode;
  const options = equalityOptions(rep.name, encode == null ? mode : "default", equals);
  options.ssrSource = rep.source;
  if (rep.deferStream) options.deferStream = true;

  const source = createMemo(() => {
    const aff = compute();

    return new Promise((resolve, reject) => {
      let done = false;
      const cancel = start(aff)((result) => () => {
        if (!done) {
          done = true;
          resolve(encode == null ? result : encode(result));
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
  }, options);

  if (rep.decode == null) return { value: source, refresh: source };

  const decode = rep.decode;
  const value = createMemo(
    () =>
      rep.either((message) => {
        throw new Error(`purs-solid: could not decode server value: ${message}`);
      })((decoded) => decoded)(decode(source())),
    equalityOptions("", mode, equals)
  );

  return { value, refresh: source };
};

export const refreshImpl = (target) => {
  // Errors surface through the graph (loading/error boundaries), not here.
  solidRefresh(target).catch(() => {});
};

export const refreshPromiseImpl = (target) => solidRefresh(target);

export const isPending = (accessor) => () => solidIsPending(accessor);

export const latest = (accessor) => () => solidLatest(accessor);

export const resolveImpl = (accessor) => solidResolve(accessor);
