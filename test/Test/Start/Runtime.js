export const mkRuntimeRequest = (method) => (path) => (headers) => (query) => (body) => ({
  method,
  path,
  headers,
  query,
  body: body?.value0
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
