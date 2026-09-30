import { createRequestEvent } from "@solidjs/web";
import { provideRequestEvent } from "@solidjs/web/storage";

// On the server (no plugin transform) a server function is just the function.
export async function echo({ name, tag }) {
  "use server";
  return { greeting: tag == null ? `hello ${name}` : `hello ${name} (${tag})` };
}

export const newRequest = (url) => (cookie) => () =>
  new Request(url, cookie === "" ? {} : { headers: { cookie } });

export const textResponse = (body) => () => new Response(body);

export const responseHeader = (name) => (response) => () => response.headers.get(name) ?? "";

export const setHeader = (name) => (value) => (response) => () => {
  response.headers.set(name, value);
};

export const runMiddleware = (middleware) => (request) => () =>
  middleware(request, async () => new Response("ok"));

export const withRequestEventImpl = (request) => (action) => () => {
  const event = createRequestEvent(request);
  const result = provideRequestEvent(event, () => action());
  return {
    result,
    status: event.response.status ?? 200,
    headers: event.response.headers.getSetCookie(),
  };
};
