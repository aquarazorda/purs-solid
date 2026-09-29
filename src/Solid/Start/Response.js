import { httpHeader, httpStatus } from "@solidjs/web";

export const httpStatusImpl = (code) => {
  httpStatus(code);
};

export const httpHeaderImpl = (name, value, append) => {
  httpHeader(name, value, append ? { append: true } : undefined);
};
