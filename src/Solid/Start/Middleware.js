export const middlewareImpl = (handler) => (request, next) => handler(request)(() => next())();
