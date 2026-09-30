import { getRequestEvent, parseCookieHeader, serializeCookie } from "@solidjs/web";

export const getRequestEventImpl = () => getRequestEvent() ?? null;

export const request = (event) => event.request;

export const cookies = (event) => parseCookieHeader(event.request.headers.get("cookie"));

const responseHeaders = (event) => {
  const headers = event.response?.headers;
  if (headers == null) throw new Error("purs-solid: this request event has no response");
  return headers;
};

export const setCookieImpl = (event, name, value, options) => {
  const cookieOptions = { path: "/", httpOnly: true, secure: true, sameSite: "lax", ...options };
  responseHeaders(event).append("set-cookie", serializeCookie(name, value, cookieOptions));
};

export const deleteCookieImpl = (event, name, options) => {
  const cookieOptions = { path: "/", ...options, maxAge: 0, expires: new Date(0) };
  responseHeaders(event).append("set-cookie", serializeCookie(name, "", cookieOptions));
};

export const setResponseStatusImpl = (event, status) => {
  event.response.status = status;
};

export const responseHeaderImpl = (event, name, value, append) => {
  const headers = responseHeaders(event);
  if (append) headers.append(name, value);
  else headers.set(name, value);
};

export const getLocalImpl = (event, name) => event.locals[name] ?? null;

export const setLocalImpl = (event, name, value) => {
  event.locals[name] = value;
};
