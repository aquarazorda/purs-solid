import { createRoot as createSolidRoot } from "solid-js/dist/solid.js";

export const createRoot = (k) => () =>
  createSolidRoot((dispose) => k(() => dispose())());
