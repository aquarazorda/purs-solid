import {
  createEffect as solidCreateEffect,
  createMemo as solidCreateMemo,
  createReaction as solidCreateReaction,
  createRenderEffect as solidCreateRenderEffect,
  createSignal as solidCreateSignal,
  flush as solidFlush,
} from "solid-js";

// Same encoding as `Solid.Signal` (FFI files can't share code without relying
// on the compiler's output layout).
const equalityOptions = (name, mode, equals) => {
  const options = {};
  if (name !== "") options.name = name;
  if (mode === "never") options.equals = false;
  else if (mode === "custom") options.equals = equals;
  return options;
};

export const createMemoImpl = (name, mode, equals, lazy, compute) => {
  const options = equalityOptions(name, mode, equals);
  if (lazy) options.lazy = true;
  return solidCreateMemo(() => compute(), options);
};

// Function form of `createSignal`. The compute result is boxed for the same
// reason as in `Solid.Signal`: a function result would otherwise be misread.
export const createWritableMemoImpl = (compute) => {
  const [getBox, setBox] = solidCreateSignal(() => ({ value: compute() }), {
    equals: (a, b) => a.value === b.value,
  });

  return {
    get: () => getBox().value,
    set: (update) => setBox((box) => ({ value: update(box.value) })),
  };
};

const toError = (error) =>
  error instanceof Error ? error : new Error(String(error));

// `apply` returns the cleanup `Effect` (a zero-argument function), which is
// exactly the shape Solid expects from an effect function.
export const createEffectImpl = (name, defer, onError, compute, apply) => {
  const options = {};
  if (name !== "") options.name = name;
  if (defer) options.defer = true;

  const effect = (value) => apply(value);

  solidCreateEffect(
    () => compute(),
    onError == null ? effect : { effect, error: (error) => onError(toError(error)) },
    options
  );
};

export const createRenderEffectImpl = (compute, apply) => {
  solidCreateRenderEffect(() => compute(), (value) => apply(value));
};

export const createReactionImpl = (onInvalidate) =>
  solidCreateReaction(() => {
    onInvalidate();
  });

export const trackImpl = (reaction, accessor) => {
  reaction(() => {
    accessor();
  });
};

export const flush = () => {
  solidFlush();
};

export const withFlushImpl = (action) => solidFlush(() => action());
