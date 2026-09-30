export const middlewareImpl = (handler) => (request, next) => handler(request)((forwarded) => () => next(forwarded))();
