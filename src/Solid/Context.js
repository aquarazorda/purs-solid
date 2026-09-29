import { createComponent, createContext, useContext } from "solid-js";

export const createContextImpl = (defaultValue) =>
  createContext(defaultValue);

export const useContextImpl = (context) =>
  useContext(context);

// In Solid 2 the context object is the provider component.
export const provideImpl = (context) => (value) => (children) =>
  createComponent(context, {
    value,
    get children() {
      return children();
    },
  });
