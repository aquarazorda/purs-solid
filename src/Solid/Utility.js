import {
  batch as solidBatch,
  getOwner as solidGetOwner,
  runWithOwner as solidRunWithOwner,
  untrack as solidUntrack,
} from "solid-js/dist/solid.js";
import * as Data_Maybe from "../Data.Maybe/index.js";

export const batch = (action) => () =>
  solidBatch(() => action());

export const untrack = (action) => () =>
  solidUntrack(() => action());

export const getOwner = () => {
  const owner = solidGetOwner();
  return owner == null
    ? Data_Maybe.Nothing.value
    : Data_Maybe.Just.create(owner);
};

export const runWithOwner = (owner) => (action) => () =>
  solidRunWithOwner(owner, () => action());

export const onImpl = (accessor) => (defer) => (run) => {
  let initialized = false;
  let previous;

  return () => {
    const current = accessor();

    if (!initialized) {
      initialized = true;
      previous = current;

      if (defer) {
        return undefined;
      }

      return run(current)(Data_Maybe.Nothing.value)();
    }

    const result = run(current)(Data_Maybe.Just.create(previous))();
    previous = current;

    return result;
  };
};
