import {
  createEffect as solidCreateEffect,
  createMemo as solidCreateMemo,
  createReaction as solidCreateReaction,
  createRenderEffect as solidCreateRenderEffect,
  createSignal as solidCreateSignal,
  flush as solidFlush,
} from "solid-js";

export const createMemoImpl = (options, compute) => solidCreateMemo(() => compute(), options);

// Boxed so Solid doesn't misread a function result as an updater.
export const createWritableMemoImpl = (options, compute) => {
  const { equals } = options;
  const [getBox, setBox] = solidCreateSignal(() => ({ value: compute() }), {
    ...options,
    equals: equals === false ? false : equals === undefined ? (a, b) => a.value === b.value : (a, b) => equals(a.value, b.value),
  });

  return {
    get: () => getBox().value,
    set: (update) => setBox((box) => ({ value: update(box.value) })),
  };
};

const toError = (error) =>
  error instanceof Error ? error : new Error(String(error));

export const createEffectImpl = (options, compute, apply) => {
  const { onError, ...rest } = options;
  const effect = (value) => apply(value);
  solidCreateEffect(
    () => compute(),
    onError === undefined ? effect : { effect, error: (error) => onError(toError(error))() },
    rest
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
