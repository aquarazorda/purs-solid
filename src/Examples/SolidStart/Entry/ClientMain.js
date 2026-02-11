export const setBootstrapMode = (mode) => () => {
  if (typeof window === "undefined") {
    return;
  }

  window.__PURS_SOLID_START_BOOTSTRAP_MODE__ = mode;
};
