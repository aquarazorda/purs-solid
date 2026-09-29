import { hydrate as solidHydrate, isServer as solidIsServer, render as solidRender } from "@solidjs/web";

export const isServer = solidIsServer;

export const renderImpl = (realize, view, mount) =>
  solidRender(() => realize(view), mount);

export const hydrateImpl = (realize, view, mount) =>
  solidHydrate(() => realize(view), mount);

export const documentBodyImpl = () =>
  typeof document === "undefined" ? null : document.body;

export const elementByIdImpl = (id) =>
  typeof document === "undefined" ? null : document.getElementById(id);
