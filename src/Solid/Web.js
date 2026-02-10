import { hydrate as solidHydrate, isServer as solidIsServer, render as solidRender } from "solid-js/web";
import * as Data_Either from "../Data.Either/index.js";
import * as Data_Maybe from "../Data.Maybe/index.js";

export const isServer = solidIsServer;

const toErrorMessage = (error) => {
  if (typeof error === "string") {
    return error;
  }

  if (error instanceof Error && typeof error.message === "string") {
    return error.message;
  }

  return String(error);
};

export const renderImpl = (view) => (mount) => () => {
  try {
    return Data_Either.Right.create(
      solidRender(() => view(), mount)
    );
  } catch (error) {
    return Data_Either.Left.create(toErrorMessage(error));
  }
};

export const hydrateImpl = (view) => (mount) => () => {
  try {
    return Data_Either.Right.create(
      solidHydrate(() => view(), mount)
    );
  } catch (error) {
    return Data_Either.Left.create(toErrorMessage(error));
  }
};

export const documentBody = () => {
  if (typeof document === "undefined" || document.body == null) {
    return Data_Maybe.Nothing.value;
  }

  return Data_Maybe.Just.create(document.body);
};

export const mountById = (id) => () => {
  if (typeof document === "undefined") {
    return Data_Maybe.Nothing.value;
  }

  const element = document.getElementById(id);

  return element == null
    ? Data_Maybe.Nothing.value
    : Data_Maybe.Just.create(element);
};
