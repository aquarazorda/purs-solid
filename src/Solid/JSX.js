import h from "solid-js/h";

export const empty = null;

export const text = (value) =>
  value;

export const fragment = (children) =>
  h(h.Fragment, null, ...children);

export const keyed = (key) => (child) =>
  h(h.Fragment, { key }, child);
