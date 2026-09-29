import { createRoot as solidCreateRoot } from "solid-js";

export const createRootImpl = (body) =>
  solidCreateRoot((dispose) => body(() => dispose()));
