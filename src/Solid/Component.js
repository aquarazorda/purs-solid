import {
  children as solidChildren,
  createComponent as solidCreateComponent,
  createUniqueId as solidCreateUniqueId,
  lazy as solidLazy,
} from "solid-js";

export const componentImpl = (render) => (props) => render(props)();

export const element = (comp) => (props) =>
  solidCreateComponent(comp, props);

export const elementKeyed = (comp) => (props) =>
  solidCreateComponent(comp, props);

export const childrenImpl = (resolveChildren) => () =>
  solidChildren(() => resolveChildren());

export const createUniqueIdImpl = () =>
  solidCreateUniqueId();

export const lazyImpl = (load) =>
  solidLazy(() => load().then((component) => ({ default: component })));
