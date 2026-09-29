import { getOwner as solidGetOwner, runWithOwner as solidRunWithOwner } from "solid-js";

export const getOwnerImpl = () => {
  const owner = solidGetOwner();
  if (owner == null) {
    throw new Error("purs-solid: Setup code ran without an owner (only possible via unsafeSetupEffect or FFI)");
  }
  return owner;
};

export const runWithOwnerImpl = (owner, action) =>
  solidRunWithOwner(owner, () => action());
