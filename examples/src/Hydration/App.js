export const countFetch = () => {
  globalThis.__pursSolidFetches = (globalThis.__pursSolidFetches ?? 0) + 1;
};
