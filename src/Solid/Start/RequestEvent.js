import { getRequestEvent, parseCookieHeader, serializeCookie } from "@solidjs/web";

export const getRequestEventImpl = () => getRequestEvent() ?? null;

export const request = (event) => event.request;

export const cookies = (event) => parseCookieHeader(event.request.headers.get("cookie"));

export const setCookieImpl = (event, name, value, options) => {
  const cookieOptions = { path: options.path, httpOnly: options.httpOnly, secure: options.secure };
  if (options.domain != null) cookieOptions.domain = options.domain;
  if (options.maxAge != null) cookieOptions.maxAge = options.maxAge;
  if (options.sameSite != null) cookieOptions.sameSite = options.sameSite;
  const headers = event.response?.headers;
  if (headers == null) throw new Error("purs-solid: this request event has no response to set a cookie on");
  headers.append("set-cookie", serializeCookie(name, value, cookieOptions));
};

export const getLocalImpl = (event, name) => event.locals[name] ?? null;

export const setLocalImpl = (event, name, value) => {
  event.locals[name] = value;
};
