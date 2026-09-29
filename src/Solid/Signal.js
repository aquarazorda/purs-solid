import { createSignal as solidCreateSignal, untrack as solidUntrack } from "solid-js";

// Options object for `createSignal` / `createMemo`: `mode` is "default" (omit
// `equals`), "never" (`equals: false`), or "custom" (use the `equals` Fn2).
const equalityOptions = (name, mode, equals) => {
  const options = {};
  if (name !== "") options.name = name;
  if (mode === "never") options.equals = false;
  else if (mode === "custom") options.equals = equals;
  return options;
};

// Solid treats a function passed to `createSignal` as a compute function and a
// function passed to a setter as an updater. PureScript functions (including
// `Effect` values) are JS functions, so function-valued signals store a box and
// expose an unboxing accessor. The type fixes whether values are functions, so
// checking the initial value is enough.
export const createSignalImpl = (name, mode, equals, initial) => {
  if (typeof initial !== "function") {
    const [get, set] = solidCreateSignal(initial, equalityOptions(name, mode, equals));
    return { get, set };
  }

  // Compare the boxed values, never the boxes (every write makes a new box).
  const boxedMode = mode === "never" ? "never" : "custom";
  const boxedEquals = mode === "custom"
    ? (a, b) => equals(a.value, b.value)
    : (a, b) => a.value === b.value;
  const [getBox, setBox] = solidCreateSignal({ value: initial }, equalityOptions(name, boxedMode, boxedEquals));

  const get = () => getBox().value;
  const set = (update) => setBox((box) => ({ value: update(box.value) }));

  return { get, set, boxed: true };
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

export const untrack = (accessor) => () => solidUntrack(accessor);

export const mapImpl = (f) => (accessor) => () => f(accessor());

export const applyImpl = (accessorF) => (accessor) => () => accessorF()(accessor());

export const pureImpl = (value) => () => value;

export const bindImpl = (accessor) => (f) => () => f(accessor())();
