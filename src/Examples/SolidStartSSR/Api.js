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

export const fetchTextImpl = (url) => () => {
  if (typeof fetch !== "function") {
    return Promise.resolve(Data_Either.Left.create("fetch is unavailable in current runtime"));
  }

  return fetch(url, {
    headers: {
      accept: "text/plain",
    },
  })
    .then(async (response) => {
      const body = await response.text();
      if (!response.ok) {
        return Data_Either.Left.create(`HTTP ${response.status}: ${body}`);
      }

      return Data_Either.Right.create(body);
    })
    .catch((error) => Data_Either.Left.create(toErrorMessage(error)));
};
