import { OBSERVE } from "solid-js";

const collectors = new Set();

export const collectDiagnostics = () => {
  if (OBSERVE?.diagnostics == null) throw new Error("Solid dev build not loaded: run with --conditions=development");
  const collected = [];
  collectors.add(collected);
  const unsubscribe = OBSERVE.diagnostics.subscribe((event) => {
    collected.push({ code: String(event.code), severity: String(event.severity), message: String(event.message) });
  });
  return () => {
    unsubscribe();
    collectors.delete(collected);
    return collected;
  };
};

// An expected diagnostic isn't reported by the enclosing `solidIt`.
export const acknowledgeImpl = (code) => () => {
  for (const collected of collectors) {
    for (let i = collected.length - 1; i >= 0; i -= 1) if (collected[i].code === code) collected.splice(i, 1);
  }
};

export const jsxValue = (jsx) => () => {
  let value = jsx;
  while (typeof value === "function") value = value();
  return Array.isArray(value) ? value.join("") : String(value);
};

export const innerHTML = (element) => () => element.innerHTML;

export const inputEvent = () => new Event("input", { bubbles: true });
