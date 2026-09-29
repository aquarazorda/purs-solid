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
