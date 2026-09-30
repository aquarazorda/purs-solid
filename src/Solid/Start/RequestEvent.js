import { getRequestEvent, parseCookieHeader, serializeCookie } from "@solidjs/web";

export const getRequestEventImpl = () => getRequestEvent() ?? null;

export const request = (event) => event.request;

export const cookies = (event) => parseCookieHeader(event.request.headers.get("cookie"));

export const setCookieImpl = (event, name, value, options) => {
  const headers = event.response?.headers;
  if (headers == null) throw new Error("purs-solid: this request event has no response to set a cookie on");
  const cookieOptions = { path: "/", httpOnly: true, secure: true, sameSite: "lax", ...options };
  headers.append("set-cookie", serializeCookie(name, value, cookieOptions));
};

export const getLocalImpl = (event, name) => event.locals[name] ?? null;

export const setLocalImpl = (event, name, value) => {
  event.locals[name] = value;
};
