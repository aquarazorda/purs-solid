import { createContext, useContext } from "solid-js";

export const createContextImpl = (defaultValue) =>
  createContext(defaultValue);

export const useContextImpl = (context) =>
  useContext(context);
