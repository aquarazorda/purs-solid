import {
  createContext as solidCreateContext,
  getOwner as solidGetOwner,
  useContext as solidUseContext,
} from "solid-js";
import * as Data_Maybe from "../Data.Maybe/index.js";

const isJust = (maybe) =>
  maybe instanceof Data_Maybe.Just;

export const createContextImpl = (defaultValue) => () =>
  isJust(defaultValue)
    ? solidCreateContext(defaultValue.value0)
    : solidCreateContext();

export const useContext = (context) => () => {
  const value = solidUseContext(context);

  return value === undefined
    ? Data_Maybe.Nothing.value
    : Data_Maybe.Just.create(value);
};

export const withContext = (context) => (value) => (action) => () => {
  const owner = solidGetOwner();

  if (owner == null) {
    return action();
  }

  const previousContext = owner.context;

  owner.context = {
    ...(owner.context || {}),
    [context.id]: value,
  };

  try {
    return action();
  } finally {
    owner.context = previousContext;
  }
};
