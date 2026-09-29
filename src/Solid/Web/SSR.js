// Server rendering. Solid 2 selects its server build through export conditions,
// so this module must run under Node's default conditions (not `browser`).
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

// `onHead` delivers everything head-bound (useHead winners, asset links,
// styles) when the output has no `</head>`, i.e. when the host owns the document.
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

// Awaiting a render stream yields the fully settled HTML (Solid 2's
// replacement for `renderToStringAsync`). Synchronous failures reject.
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
