export const mkRuntimeRequest = (method) => (path) => (headers) => (query) => (body) => ({
  method,
  path,
  headers,
  query,
  body: body?.value0
});
