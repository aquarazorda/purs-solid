// Server rendering. Solid 2 selects its server build through export conditions,
// so this module must run under Node's default conditions (not `browser`).
import {
  generateHydrationScript as solidGenerateHydrationScript,
  renderToStream as solidRenderToStream,
  renderToString as solidRenderToString,
} from "@solidjs/web";

export const renderToStringImpl = (view) =>
  solidRenderToString(() => view());

// `onHead` delivers everything head-bound (useHead winners, asset links,
// styles) when the output has no `</head>`, i.e. when the host owns the document.
export const renderToStringWithHeadImpl = (view) => {
  let head = "";
  const html = solidRenderToString(() => view(), {
    onHead: (value) => {
      head = value;
    },
  });
  return { html, head };
};

// Solid 2 removed `renderToStringAsync`; awaiting a stream yields the fully
// settled HTML. Synchronous failures surface as a rejected promise.
export const renderToStringAsyncImpl = (view) => {
  try {
    return Promise.resolve(solidRenderToStream(() => view()));
  } catch (error) {
    return Promise.reject(error);
  }
};

export const renderToStreamImpl = (view) =>
  solidRenderToStream(() => view());

export const hydrationScriptImpl = () =>
  solidGenerateHydrationScript();
