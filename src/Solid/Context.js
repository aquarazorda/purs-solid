import { createContext, useContext } from "solid-js";

// Boxed: Solid treats `undefined` (PureScript's `unit`) as "not provided".
export const createContextImpl = (defaultValue) => createContext({ value: defaultValue });

export const useContextImpl = (context) => useContext(context).value;
