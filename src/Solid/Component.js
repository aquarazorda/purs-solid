import h from "solid-js/h";
import {
  children as solidChildren,
  createUniqueId as solidCreateUniqueId,
  lazy as solidLazy,
} from "solid-js/dist/solid.js";

export const component = (render) => {
  const wrapped = (props) =>
    render(props)();

  return wrapped;
};

export const element = (comp) => (props) =>
  h(comp, props);

export const elementKeyed = (comp) => (props) =>
  h(comp, props);

export const children = (resolveChildren) => () =>
  solidChildren(() => resolveChildren());

export const createUniqueId = () =>
  solidCreateUniqueId();

export const lazy = (loadComponent) =>
  solidLazy(() =>
    Promise.resolve({
      default: loadComponent(),
    })
  );
