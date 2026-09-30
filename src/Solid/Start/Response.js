import { httpHeader } from "@solidjs/web";

export { httpStatus as httpStatusImpl } from "@solidjs/web";

export const httpHeaderImpl = (name, value, append) => httpHeader(name, value, append ? { append: true } : undefined);
