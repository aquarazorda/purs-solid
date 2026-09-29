// The diagnostics channel is part of the observe tier (dev and observe builds).
import { OBSERVE } from "solid-js";

export const collectDiagnostics = () => {
  if (OBSERVE == null || OBSERVE.diagnostics == null) {
    throw new Error("Solid dev build not loaded: run the client tests with --conditions=development");
  }

  const collected = [];
  const unsubscribe = OBSERVE.diagnostics.subscribe((event) => {
    collected.push({ code: String(event.code), severity: String(event.severity), message: String(event.message) });
  });

  return () => {
    unsubscribe();
    return collected;
  };
};

export const jsxValue = (jsx) => () => {
  let value = jsx;
  while (typeof value === "function") value = value();
  return Array.isArray(value) ? value.join("") : String(value);
};

export const refEq = (a) => (b) => a === b;

export const createContainer = () => {
  const container = document.createElement("div");
  document.body.appendChild(container);
  return container;
};

export const removeContainer = (container) => () => {
  container.remove();
};

export const innerHtml = (element) => () => element.innerHTML;

export const querySelectorImpl = (selector) => (element) => () => element.querySelector(selector);

export const click = (element) => () => {
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, composed: true }));
};

export const inputText = (value) => (element) => () => {
  element.value = value;
  element.dispatchEvent(new Event("input", { bubbles: true, composed: true }));
};

export const attributeImpl = (name) => (element) => () => element.getAttribute(name);

export const namespaceOf = (element) => () => element.namespaceURI;
