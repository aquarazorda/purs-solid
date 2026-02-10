import h from "solid-js/h";

export const element = (tag) => (props) => (children) =>
  h(tag, { ...props, children });

export const element_ = (tag) => (children) =>
  h(tag, { children });
