import {
  createMemo,
  isPending as solidIsPending,
  latest as solidLatest,
  onCleanup,
  refresh as solidRefresh,
  resolve as solidResolve,
  until as solidUntil,
} from "solid-js";

const toError = (error) => (error instanceof Error ? error : new Error(String(error)));

const onClient = { source: "client", encode: null, decode: null };

// With a codec, the memo holds the encoded value (what Solid serializes) and a
// second memo decodes it.
export const createAsyncImpl = (start, either, options, compute) => {
  const { ssr = onClient, equals, ...rest } = options;
  const { encode, decode } = ssr;
  const sourceOptions = { ...rest, ssrSource: ssr.source };
  if ("loadingValue" in options && encode != null) sourceOptions.loadingValue = encode(options.loadingValue);
  if (encode == null && equals !== undefined) sourceOptions.equals = equals;

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
  }, sourceOptions);

  if (decode == null) return { value: source, refresh: source };

  const value = createMemo(
    () =>
      either((message) => {
        throw new Error(`purs-solid: could not decode server value: ${message}`);
      })((decoded) => decoded)(decode(source())),
    equals === undefined ? undefined : { equals }
  );

  return { value, refresh: source };
};

export const refreshImpl = (target) => {
  // Errors surface through the graph, not here.
  solidRefresh(target).catch(() => {});
};

export const refreshPromiseImpl = (target) => solidRefresh(target);

export const isPending = (accessor) => () => solidIsPending(accessor);

export const latest = (accessor) => () => solidLatest(accessor);

export const resolveImpl = (accessor) => solidResolve(accessor);

export const untilImpl = (options, predicate, onValue, onError) => {
  const controller = new AbortController();
  solidUntil(predicate, { ...options, signal: controller.signal }).then(onValue, (error) => {
    if (!controller.signal.aborted) onError(toError(error));
  });
  return () => controller.abort();
};
