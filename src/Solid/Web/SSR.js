import {
  generateHydrationScript as solidGenerateHydrationScript,
  renderToStream as solidRenderToStream,
  renderToString as solidRenderToString,
} from "@solidjs/web";

const toError = (error) => (error instanceof Error ? error : new Error(String(error)));

// The hook only reports; returning nothing keeps Solid's default client-facing value.
const writer = (hook) => (info) => {
  hook((html) => () => info.write(html))();
};

const toSolid = ({ onError, onCompleteShell, onCompleteAll, ...rest }) => {
  const options = { ...rest };
  if (onError !== undefined) {
    options.onError = (error) => {
      onError(toError(error))();
    };
  }
  if (onCompleteShell !== undefined) options.onCompleteShell = writer(onCompleteShell);
  if (onCompleteAll !== undefined) options.onCompleteAll = writer(onCompleteAll);
  return options;
};

export const renderToStringImpl = (realize, options, view) =>
  solidRenderToString(() => realize(view), toSolid(options));

export const renderToStringWithHeadImpl = (realize, options, view) => {
  let head = "";
  const html = solidRenderToString(() => realize(view), {
    ...toSolid(options),
    onHead: (value) => {
      head = value;
    },
  });
  return { html, head };
};

// An awaited render stream resolves to the fully settled HTML.
export const renderToStringAsyncImpl = (realize, options, view) => {
  try {
    return Promise.resolve(solidRenderToStream(() => realize(view), toSolid(options)));
  } catch (error) {
    return Promise.reject(error);
  }
};

export const renderToReadableStreamImpl = (realize, options, view) =>
  solidRenderToStream(() => realize(view), toSolid(options)).readable;

export const hydrationScriptImpl = (options) => solidGenerateHydrationScript(options);
