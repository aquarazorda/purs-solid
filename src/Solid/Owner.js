import { getOwner } from "solid-js";

export { runWithOwner as runWithOwnerImpl } from "solid-js";

export const getOwnerImpl = () => {
  const owner = getOwner();
  if (owner == null) throw new Error("purs-solid: Setup code ran without an owner");
  return owner;
};
