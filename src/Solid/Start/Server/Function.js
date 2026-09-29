// Resolves with the response text. Failures reject with an Error whose message is
// either a `START_ERROR:<kind>:<text>` wire string or a transport description.
export const httpPostTransportImpl = (endpoint) => (payload) => () => {
  if (typeof fetch !== "function") {
    return Promise.reject(new Error("fetch is unavailable in current runtime"));
  }

  return fetch(endpoint, {
    method: "POST",
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "accept": "text/plain",
    },
    body: payload,
  }).then(async (response) => {
    const text = await response.text();

    if (!response.ok) {
      const errorKind = response.headers.get("x-start-error-kind");
      if (typeof errorKind === "string" && errorKind.length > 0) {
        throw new Error(`START_ERROR:${errorKind}:${text}`);
      }

      throw new Error(`HTTP ${response.status}: ${text}`);
    }

    return text;
  });
};
