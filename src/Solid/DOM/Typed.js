import { createComponent as solidCreateComponent } from "solid-js";
import { Dynamic as solidDynamic } from "solid-js/web";

const toPropsObject = (props) => {
  const result = {};

  if (!Array.isArray(props)) {
    return result;
  }

  for (const entry of props) {
    if (entry == null || typeof entry !== "object") {
      continue;
    }

    const key = entry.key;
    if (typeof key !== "string" || key.length === 0) {
      continue;
    }

    result[key] = entry.value;
  }

  return result;
};

export const customProp = (key) => (value) => ({ key, value });

export const render = (tag) => (props) => (children) =>
  solidCreateComponent(solidDynamic, {
    component: tag,
    ...toPropsObject(props),
    children,
  });

export const render_ = (tag) => (children) =>
  solidCreateComponent(solidDynamic, {
    component: tag,
    children,
  });
