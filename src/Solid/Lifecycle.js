import { onCleanup as solidOnCleanup, onMount as solidOnMount } from "solid-js/dist/solid.js";

export const onCleanup = (action) => () => {
  solidOnCleanup(() => {
    action();
  });
};

export const onMount = (action) => () => {
  solidOnMount(() => {
    action();
  });
};
