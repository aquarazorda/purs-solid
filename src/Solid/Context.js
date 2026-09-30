import { createContext, useContext } from "solid-js";

const contexts = new Map();

// Boxed: Solid treats `undefined` (PureScript's `unit`) as "not provided".
export const createContextImpl = (name, defaultValue) => {
  if (!contexts.has(name)) contexts.set(name, createContext({ value: defaultValue }, { name }));
  return contexts.get(name);
};

export const useContextImpl = (context) => useContext(context).value;
