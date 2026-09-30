import { httpHeader, redirect, reload, respond } from "@solidjs/web";

export { httpStatus as httpStatusImpl, httpStatus as httpStatusTextImpl } from "@solidjs/web";

export const httpHeaderImpl = (name, value, append) => httpHeader(name, value, append ? { append: true } : undefined);

export const redirectImpl = (url) => (options) => redirect(url, options);

export const reloadImpl = (options) => reload(options);

export const respondImpl = (value) => (options) => respond(value, options);
