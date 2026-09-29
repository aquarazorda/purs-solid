import {
  createContext as solidCreateContext,
  getOwner as solidGetOwner,
  useContext as solidUseContext,
} from "solid-js";

export const createContextImpl = () =>
  solidCreateContext();

export const createContextWithDefaultImpl = (defaultValue) =>
  solidCreateContext(defaultValue);

// Missing context is `undefined`; the PureScript side turns it into `Nothing`.
export const useContextImpl = (context) =>
  solidUseContext(context);

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
