import { hydrate as solidHydrate, render as solidRender } from "@solidjs/web";

export const isServer = typeof window === "undefined" || typeof document === "undefined";

export const renderImpl = (view, mount) =>
  solidRender(() => view(), mount);

export const hydrateImpl = (view, mount) =>
  solidHydrate(() => view(), mount);

export const documentBodyImpl = () =>
  typeof document === "undefined" ? null : document.body;

export const mountByIdImpl = (id) =>
  typeof document === "undefined" ? null : document.getElementById(id);
