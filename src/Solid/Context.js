import { createContext, useContext } from "solid-js";

// Boxed: Solid treats `undefined` (PureScript's `unit`) as "not provided".
export const createContextImpl = (name, defaultValue) =>
  createContext({ value: defaultValue }, name === "" ? undefined : { name });

export const useContextImpl = (context) => useContext(context).value;
