import { createEffect as createSolidEffect, createMemo as createSolidMemo } from "solid-js/dist/solid.js";

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
