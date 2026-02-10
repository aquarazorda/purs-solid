import {
  createComputed as createSolidComputed,
  createDeferred as createSolidDeferred,
  createEffect as createSolidEffect,
  createMemo as createSolidMemo,
  createReaction as createSolidReaction,
  createRenderEffect as createSolidRenderEffect,
  createSelector as createSolidSelector,
} from "solid-js/dist/solid.js";

const makeMemoOptions = (name) => {
  const options = {};

  if (name !== "") {
    options.name = name;
  }

  return options;
};

export const createMemoWithDefaultEqImpl = (name) => (compute) => () =>
  createSolidMemo(() => compute(), undefined, makeMemoOptions(name));

export const createMemoWithAlwaysImpl = (name) => (compute) => () => {
  const options = makeMemoOptions(name);
  options.equals = false;

  return createSolidMemo(() => compute(), undefined, options);
};

export const createMemoWithCustomEqImpl = (name) => (equals) => (compute) => () => {
  const options = makeMemoOptions(name);
  options.equals = (prev, next) => equals(prev)(next);

  return createSolidMemo(() => compute(), undefined, options);
};

export const createEffect = (action) => () => {
  createSolidEffect(() => {
    action();
  });
};

export const createComputed = (action) => () => {
  createSolidComputed(() => {
    action();
  });
};

export const createRenderEffect = (action) => () => {
  createSolidRenderEffect(() => {
    action();
  });
};

export const createReaction = (onInvalidate) => () => {
  const track = createSolidReaction(() => {
    onInvalidate();
  });

  return (observe) => () => {
    track(() => {
      observe();
    });
  };
};

export const createDeferred = (source) => () =>
  createSolidDeferred(source);

export const createSelector = (source) => () => {
  const selector = createSolidSelector(source);

  return (key) => () =>
    selector(key);
};
