import { createSignal } from "solid-js/dist/solid.js";

const makeOptions = (name, internal) => {
  const options = {};

  if (name !== "") {
    options.name = name;
  }

  if (internal) {
    options.internal = true;
  }

  return options;
};

const toParts = (signal) => ({ get: signal[0], set: signal[1] });

export const createSignalWithDefaultEqImpl = (name) => (internal) => (initial) => () =>
  toParts(createSignal(initial, makeOptions(name, internal)));

export const createSignalWithAlwaysImpl = (name) => (internal) => (initial) => () => {
  const options = makeOptions(name, internal);
  options.equals = false;

  return toParts(createSignal(initial, options));
};

export const createSignalWithCustomEqImpl = (name) => (internal) => (equals) => (initial) => () => {
  const options = makeOptions(name, internal);
  options.equals = (prev, next) => equals(prev)(next);

  return toParts(createSignal(initial, options));
};

export const get = (accessor) => () => accessor();

export const set = (setter) => (value) => () =>
  setter(() => value);

export const modify = (setter) => (update) => () =>
  setter((prev) => update(prev));
