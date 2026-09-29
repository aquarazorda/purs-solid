import {
  generateHydrationScript as solidGenerateHydrationScript,
  renderToStream as solidRenderToStream,
  renderToString as solidRenderToString,
} from "@solidjs/web";

const toOptions = (rep) => {
  const options = {};
  if (rep.nonce != null) options.nonce = rep.nonce;
  if (rep.renderId != null) options.renderId = rep.renderId;
  if (rep.noScripts) options.noScripts = true;
  return options;
};

export const renderToStringImpl = (realize, rep, view) =>
  solidRenderToString(() => realize(view), toOptions(rep));

export const renderToStringWithHeadImpl = (realize, rep, view) => {
  let head = "";
  const html = solidRenderToString(() => realize(view), {
    ...toOptions(rep),
    onHead: (value) => {
      head = value;
    },
  });
  return { html, head };
};

// An awaited render stream resolves to the fully settled HTML.
export const renderToStringAsyncImpl = (realize, rep, view) => {
  try {
    return Promise.resolve(solidRenderToStream(() => realize(view), toOptions(rep)));
  } catch (error) {
    return Promise.reject(error);
  }
};

export const renderToReadableStreamImpl = (realize, rep, view) =>
  solidRenderToStream(() => realize(view), toOptions(rep)).readable;

export const hydrationScriptImpl = (nonce) =>
  solidGenerateHydrationScript(nonce == null ? {} : { nonce });
