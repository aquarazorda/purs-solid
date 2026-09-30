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
  middleware(request, async (forwarded) => new Response(`ok ${(forwarded ?? request).url}`));

export const responseText = (response) => () => response.text();

// A Reply is a Response (redirect, reload), a ResponseEnvelope, or the plain value.
export const replyInfo = (value) => {
  if (value instanceof Response) {
    return {
      status: value.status,
      location: value.headers.get("location") ?? "",
      revalidate: value.headers.get("x-revalidate") ?? "",
      value: null,
    };
  }
  if (value != null && typeof value === "object" && "response" in value && "value" in value) {
    return { status: 0, location: "", revalidate: value.response?.headers.get("x-revalidate") ?? "", value: value.value };
  }
  return { status: 0, location: "", revalidate: "", value };
};

export const withRequestEventImpl = (request) => (action) => () => {
  const event = createRequestEvent(request);
  const result = provideRequestEvent(event, () => action());
  return {
    result,
    status: event.response.status ?? 200,
    headers: event.response.headers.getSetCookie(),
    trace: event.response.headers.get("x-trace") ?? "",
  };
};
