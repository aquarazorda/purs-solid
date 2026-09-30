import {
  browserHistory as solidBrowserHistory,
  createRouter as solidCreateRouter,
  hashHistory as solidHashHistory,
  int,
  memoryHistory as solidMemoryHistory,
  useBeforeLeave,
  useIsRouting as solidUseIsRouting,
  useLinkState,
  useLocation as solidUseLocation,
  useMatch as solidUseMatch,
  useNavigate as solidUseNavigate,
  usePreloadRoute,
  useResolvedPath,
  useSearchParams,
} from "@solidjs/router";
import { createComponent } from "solid-js";

const filters = { int };

const readParams = (pattern, just, nothing) => (params) => {
  const record = {};
  for (const param of pattern.params) {
    const raw = params[param.name];
    const value = raw != null && param.filter === "int" ? Number.parseInt(raw, 10) : raw;
    record[param.name] = param.optional ? (value == null ? nothing : just(value)) : (value ?? "");
  }
  return record;
};

export const routeImpl = (spec) => {
  const { pattern, options } = spec;
  const toParams = readParams(pattern, spec.just, spec.nothing);

  const definition = {
    path: pattern.path,
    component: (props) =>
      spec.realize(
        spec.render({
          params: () => toParams(props.params),
          children: () => props.children,
        })()
      ),
  };

  const matchFilters = {};
  for (const param of pattern.params) if (param.filter !== null) matchFilters[param.name] = filters[param.filter];
  if (Object.keys(matchFilters).length > 0) definition.matchFilters = matchFilters;

  if (options.preload !== undefined) {
    definition.preload = (args) => {
      options.preload({ params: toParams(args.params), intent: args.intent })();
    };
  }

  // An array of child routes, or an Effect that imports a module exporting `routes`.
  const { children } = spec;
  if (Array.isArray(children)) {
    if (children.length > 0) definition.children = children;
  } else definition.children = () => children();
  return definition;
};

export const browserHistoryImpl = () => solidBrowserHistory();
export const hashHistoryImpl = () => solidHashHistory();
export const memoryHistoryImpl = (url) => () => solidMemoryHistory(url);

export const createRouterImpl = (options) => solidCreateRouter(options);

export const routerViewImpl = (router) => (url) => (root) => (realize) => () =>
  createComponent(router, {
    ...(url == null ? {} : { url }),
    children: (props) => realize(root(() => props.children)()),
  });

export const useLocationImpl = () => solidUseLocation();

export const pathname = (location) => () => location.pathname;
export const search = (location) => () => location.search;
export const hash = (location) => () => location.hash;

export const queryParamImpl = (name) => (location) => () => {
  const value = location.query[name];
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
};

export const queryParams = (name) => (location) => () => {
  const value = location.query[name];
  return value == null ? [] : Array.isArray(value) ? value : [value];
};

export const locationStateImpl = (location) => () => location.state ?? null;

export const locationKey = (location) => () => location.key;

export const useSearchParamsImpl = () => useSearchParams()[1];

export const setSearchParamsImpl = (setter, params, options) => {
  setter(params, options);
};

export const useIsRoutingImpl = () => solidUseIsRouting();

export const useMatchImpl = (pattern) => {
  const match = solidUseMatch(() => pattern);
  return () => match() !== undefined;
};

export const useLinkStateImpl = (to) => useLinkState(to);

export const useResolvedPathImpl = (path) => {
  const resolved = useResolvedPath(path);
  return () => resolved() ?? null;
};

export const usePreloadRouteImpl = () => {
  const preload = usePreloadRoute();
  return (url) => () => preload(url, { preloadData: true });
};

export const useBeforeLeaveImpl = (listener) => {
  useBeforeLeave((event) => {
    listener({
      to: String(event.to),
      defaultPrevented: event.defaultPrevented,
      preventDefault: () => event.preventDefault(),
      retry: () => event.retry(),
      forceRetry: () => event.retry(true),
    })();
  });
};

export const useNavigateImpl = () => solidUseNavigate();

export const navigateImpl = (navigate, to, options) => {
  navigate(to, options);
};

export const goImpl = (navigate, delta) => {
  navigate(delta);
};
