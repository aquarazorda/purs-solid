const normalizeBasePath = (basePath) => {
  if (typeof basePath !== "string" || basePath.length === 0) {
    return "";
  }

  if (basePath === "/") {
    return "";
  }

  let normalized = basePath;

  if (!normalized.startsWith("/")) {
    normalized = `/${normalized}`;
  }

  if (normalized.endsWith("/")) {
    normalized = normalized.slice(0, -1);
  }

  return normalized;
};

const normalizePath = (pathname, basePath) => {
  if (typeof pathname !== "string" || pathname.length === 0) {
    return "/";
  }

  const base = normalizeBasePath(basePath);
  let path = pathname;

  if (base !== "") {
    if (path === base || path === `${base}/`) {
      return "/";
    }

    if (path.startsWith(`${base}/`)) {
      path = path.slice(base.length);
    }
  }

  if (!path.startsWith("/")) {
    path = `/${path}`;
  }

  if (path.length > 1 && path.endsWith("/")) {
    path = path.slice(0, -1);
  }

  return path;
};

const toDocumentPath = (basePath, routePath) => {
  const base = normalizeBasePath(basePath);
  if (routePath === "/") {
    return base === "" ? "/" : `${base}/`;
  }

  if (base === "") {
    return `${routePath}/`;
  }

  return `${base}${routePath}/`;
};

const ensureStylesheet = (id, href) => {
  if (typeof document === "undefined") {
    return;
  }

  let link = document.getElementById(id);

  if (!(link instanceof HTMLLinkElement)) {
    link = document.createElement("link");
    link.id = id;
    link.rel = "stylesheet";
    document.head.appendChild(link);
  }

  if (link.href !== href && link.getAttribute("href") !== href) {
    link.href = href;
  }
};

const removeStylesheet = (id) => {
  if (typeof document === "undefined") {
    return;
  }

  const node = document.getElementById(id);
  if (node != null) {
    node.remove();
  }
};

export const startRoutePath = (basePath) => () => {
  if (typeof window === "undefined" || window.location == null) {
    return "/";
  }

  return normalizePath(window.location.pathname, basePath);
};

export const navigateToRoutePath = (basePath) => (routePath) => () => {
  if (typeof window === "undefined" || window.location == null || window.history == null) {
    return routePath;
  }

  const nextDocumentPath = toDocumentPath(basePath, routePath);
  if (window.location.pathname !== nextDocumentPath) {
    window.history.pushState({}, "", nextDocumentPath);
  }

  return normalizePath(window.location.pathname, basePath);
};

export const navigateFromClick = (event) => (basePath) => (routePath) => () => {
  if (event != null && typeof event.preventDefault === "function") {
    event.preventDefault();
  }

  return navigateToRoutePath(basePath)(routePath)();
};

export const subscribeRouteChanges = (basePath) => (notify) => () => {
  if (typeof window === "undefined") {
    return () => {};
  }

  const listener = () => {
    notify(normalizePath(window.location.pathname, basePath))();
  };

  window.addEventListener("popstate", listener);

  return () => {
    window.removeEventListener("popstate", listener);
  };
};

export const applyRouteStyles = (styles) => (routePath) => () => {
  if (!Array.isArray(styles)) {
    return;
  }

  const active = styles.find((entry) => entry.route === routePath);

  for (const entry of styles) {
    if (entry == null || typeof entry.id !== "string") {
      continue;
    }

    if (active != null && entry.id === active.id) {
      ensureStylesheet(entry.id, entry.href);
    } else {
      removeStylesheet(entry.id);
    }
  }
};
