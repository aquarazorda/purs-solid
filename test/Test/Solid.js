import { OBSERVE } from "solid-js";

export const collectDiagnostics = () => {
  if (OBSERVE?.diagnostics == null) throw new Error("Solid dev build not loaded: run with --conditions=development");
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

export const innerHTML = (element) => () => element.innerHTML;

export const inputEvent = () => new Event("input", { bubbles: true });
