import { createSignal as solidCreateSignal, untrack as solidUntrack } from "solid-js";

// Solid treats function values as compute functions / updaters, so box them
// and compare the boxed values, never the boxes (every write makes a new box).
export const createSignalImpl = (options, initial) => {
  if (typeof initial !== "function") {
    const [get, set] = solidCreateSignal(initial, options);
    return { get, set };
  }

  const { equals } = options;
  const [getBox, setBox] = solidCreateSignal(
    { value: initial },
    { ...options, equals: equals === false ? false : equals === undefined ? (a, b) => a.value === b.value : (a, b) => equals(a.value, b.value) }
  );

  const get = () => getBox().value;
  const set = (update) => setBox((box) => ({ value: update(box.value) }));

  return { get, set };
};

// Setters always receive an updater so values are never interpreted as one.
export const setImpl = (setter, value) => {
  setter(() => value);
};

export const modifyImpl = (setter, update) => {
  let written;
  setter((previous) => (written = update(previous)));
  return written;
};

// `Accessor` is a zero-argument function, like `Effect`: reading is calling.
export const get = (accessor) => accessor;

export const untrackImpl = (accessor) => () => solidUntrack(accessor);
