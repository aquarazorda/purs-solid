import {
  generateHydrationScript as solidGenerateHydrationScript,
  renderToStream as solidRenderToStream,
  renderToString as solidRenderToString,
  renderToStringAsync as solidRenderToStringAsync,
} from "solid-js/web";
import * as Data_Either from "../Data.Either/index.js";

const toErrorMessage = (error) => {
  if (typeof error === "string") {
    return error;
  }

  if (error instanceof Error && typeof error.message === "string") {
    return error.message;
  }

  return String(error);
};

const requireFunction = (candidate, name) => {
  if (typeof candidate !== "function") {
    throw new Error(`${name} is unavailable in current runtime`);
  }

  return candidate;
};

export const renderToStringImpl = (view) => () => {
  try {
    const renderFn = requireFunction(solidRenderToString, "renderToString");
    return Data_Either.Right.create(renderFn(() => view()));
  } catch (error) {
    return Data_Either.Left.create(toErrorMessage(error));
  }
};

export const renderToStringAsyncImpl = (view) => () => {
  try {
    const renderFn = requireFunction(solidRenderToStringAsync, "renderToStringAsync");

    return Promise.resolve(renderFn(() => view()))
      .then((html) => Data_Either.Right.create(html))
      .catch((error) => Data_Either.Left.create(toErrorMessage(error)));
  } catch (error) {
    return Promise.resolve(Data_Either.Left.create(toErrorMessage(error)));
  }
};

export const renderToStreamImpl = (view) => () => {
  try {
    const renderFn = requireFunction(solidRenderToStream, "renderToStream");
    return Data_Either.Right.create(renderFn(() => view()));
  } catch (error) {
    return Data_Either.Left.create(toErrorMessage(error));
  }
};

export const hydrationScriptImpl = () => {
  try {
    const scriptFn = requireFunction(solidGenerateHydrationScript, "generateHydrationScript");
    return Data_Either.Right.create(scriptFn());
  } catch (error) {
    return Data_Either.Left.create(toErrorMessage(error));
  }
};
