import {
  createComponent as solidCreateComponent,
  children as solidChildren,
  createUniqueId as solidCreateUniqueId,
  lazy as solidLazy,
} from "solid-js";

export const component = (render) => {
  const wrapped = (props) =>
    render(props)();

  return wrapped;
};

export const element = (comp) => (props) =>
  solidCreateComponent(comp, props);

export const elementKeyed = (comp) => (props) =>
  solidCreateComponent(comp, props);

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
