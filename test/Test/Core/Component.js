import { createRenderEffect } from "solid-js";
import { insert } from "@solidjs/web";

// A component as a JS library would write it, without the JSX compiler.
export const badge = (props) => {
  const element = document.createElement("span");
  createRenderEffect(
    () => props.label + (props.suffix ?? "!"),
    (text) => {
      element.textContent = text;
    }
  );
  element.addEventListener("click", () => props.onPick(props.label));
  const item = document.createElement("i");
  insert(item, () => props.renderItem(props.label.length));
  const content = document.createElement("b");
  insert(content, () => props.children);
  return [element, item, content];
};

export const clickFirstSpan = (root) => () => root.querySelector("span").click();

// Stands in for a dynamic `import()`: resolves to the component a moment later.
export const loadLater = (component) => () => new Promise((resolve) => setTimeout(() => resolve(component), 5));
