import {
  generateHydrationScript as solidGenerateHydrationScript,
  renderToStream as solidRenderToStream,
  renderToString as solidRenderToString,
} from "@solidjs/web";

export const renderToStringImpl = (realize, options, view) =>
  solidRenderToString(() => realize(view), options);

export const renderToStringWithHeadImpl = (realize, options, view) => {
  let head = "";
  const html = solidRenderToString(() => realize(view), {
    ...options,
    onHead: (value) => {
      head = value;
    },
  });
  return { html, head };
};

// An awaited render stream resolves to the fully settled HTML.
export const renderToStringAsyncImpl = (realize, options, view) => {
  try {
    return Promise.resolve(solidRenderToStream(() => realize(view), options));
  } catch (error) {
    return Promise.reject(error);
  }
};

export const renderToReadableStreamImpl = (realize, options, view) =>
  solidRenderToStream(() => realize(view), options).readable;

export const hydrationScriptImpl = (options) => solidGenerateHydrationScript(options);
