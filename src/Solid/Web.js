import { hydrate, isServer as solidIsServer, render } from "@solidjs/web";

export const isServer = solidIsServer;

export const renderImpl = (realize, view, mount) => render(() => realize(view), mount);

export const hydrateImpl = (realize, view, mount) => hydrate(() => realize(view), mount);
