import { hydrate as solidHydrate, isServer as solidIsServer, render as solidRender } from "solid-js/web";
import * as Data_Maybe from "../Data.Maybe/index.js";

export const isServer = solidIsServer;

export const render = (view) => (mount) => () =>
  solidRender(() => view(), mount);

export const hydrate = (view) => (mount) => () =>
  solidHydrate(() => view(), mount);

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
