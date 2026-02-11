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

export const httpPostTransportImpl = (endpoint) => (payload) => () => {
  if (typeof fetch !== "function") {
    return Promise.resolve(
      Data_Either.Left.create("fetch is unavailable in current runtime")
    );
  }

  return fetch(endpoint, {
    method: "POST",
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "accept": "text/plain",
    },
    body: payload,
  })
    .then(async (response) => {
      const text = await response.text();

      if (!response.ok) {
        const errorKind = response.headers.get("x-start-error-kind");
        if (typeof errorKind === "string" && errorKind.length > 0) {
          return Data_Either.Left.create(`START_ERROR:${errorKind}:${text}`);
        }

        return Data_Either.Left.create(`HTTP ${response.status}: ${text}`);
      }

      return Data_Either.Right.create(text);
    })
    .catch((error) => Data_Either.Left.create(toErrorMessage(error)));
};
