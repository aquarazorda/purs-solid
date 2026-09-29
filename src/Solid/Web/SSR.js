import {
  getAssets as solidGetAssets,
  generateHydrationScript as solidGenerateHydrationScript,
  renderToStream as solidRenderToStream,
  renderToString as solidRenderToString,
  renderToStringAsync as solidRenderToStringAsync,
} from "solid-js/web/dist/server.js";

const requireFunction = (candidate, name) => {
  if (typeof candidate !== "function") {
    throw new Error(`${name} is unavailable in current runtime`);
  }

  return candidate;
};

export const renderToStringImpl = (view) =>
  requireFunction(solidRenderToString, "renderToString")(() => view());

// Synchronous failures surface as a rejected promise so callers only handle one error path.
export const renderToStringAsyncImpl = (view) => {
  try {
    return Promise.resolve(requireFunction(solidRenderToStringAsync, "renderToStringAsync")(() => view()));
  } catch (error) {
    return Promise.reject(error);
  }
};

export const renderToStreamImpl = (view) =>
  requireFunction(solidRenderToStream, "renderToStream")(() => view());

export const hydrationScriptImpl = () =>
  requireFunction(solidGenerateHydrationScript, "generateHydrationScript")();

export const getAssetsImpl = () =>
  requireFunction(solidGetAssets, "getAssets")();
