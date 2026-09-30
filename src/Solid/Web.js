import { hydrate, isServer as solidIsServer, render } from "@solidjs/web";

export const isServer = solidIsServer;

const toError = (error) => (error instanceof Error ? error : new Error(String(error)));

const toSolid = ({ onError, ...rest }) =>
  onError === undefined ? rest : { ...rest, onError: (error) => onError(toError(error))() };

export const renderImpl = (realize, options, view, mount) =>
  render(() => realize(view), mount, undefined, toSolid(options));

export const hydrateImpl = (realize, options, view, mount) => hydrate(() => realize(view), mount, toSolid(options));
