import { onCleanup as solidOnCleanup, onSettled as solidOnSettled } from "solid-js";

export const onCleanupImpl = (cleanup) => {
  solidOnCleanup(() => {
    cleanup();
  });
};

// The callback returns the cleanup `Effect`, the shape `onSettled` expects.
export const onSettledImpl = (callback) => {
  solidOnSettled(() => callback());
};
