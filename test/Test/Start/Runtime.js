export const mkRuntimeRequestImpl = (method) => (path) => (headers) => (query) => (body) => ({
  method,
  path,
  headers,
  query,
  body
});

export const mkWebRuntimeRequest = () =>
  new Request("https://example.test/api/users?page=3", {
    method: "POST",
    headers: {
      "accept": "application/json",
      "x-auth": "token",
      "content-type": "application/json"
    },
    body: "{\"ping\":true}"
  });

export const mkRuntimeRequestWithInvalidPairs = {
  method: "GET",
  path: "/api/users",
  headers: [
    { name: "accept", value: "application/json" },
    ["x-test", "ok"],
    null,
    { name: "", value: "drop-me" },
    { key: "invalid" }
  ],
  query: [
    { name: "page", value: "2" },
    ["debug", "1"],
    ["invalid"],
    { name: "", value: "drop-me" },
    true
  ],
  body: null
};
