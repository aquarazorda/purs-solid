export const setBootstrapMode = (mode) => () => {
  if (typeof window === "undefined") {
    return;
  }

  window.__PURS_SOLID_SSR_SMOKE_MODE__ = mode;
};
