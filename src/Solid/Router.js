import {
  browserHistory as solidBrowserHistory,
  createRouter as solidCreateRouter,
  hashHistory as solidHashHistory,
  memoryHistory as solidMemoryHistory,
  useIsRouting as solidUseIsRouting,
  useLocation as solidUseLocation,
  useMatch as solidUseMatch,
  useNavigate as solidUseNavigate,
} from "@solidjs/router";
import { createComponent } from "solid-js";

// A route's component receives the router's props; the PureScript component
// gets its declared params as an accessor of a record (optional params as
// `Maybe`) and the matched child route as lazy JSX.
export const routeImpl = (spec) => {
  const toParams = (params) => () => {
    const record = {};
    for (const field of spec.fields) {
      const value = params[field.name];
      record[field.name] = field.optional
        ? (value == null ? spec.nothing : spec.just(value))
        : (value ?? "");
    }
    return record;
  };

  const definition = {
    path: spec.path,
    component: (props) =>
      spec.realize(
        spec.render({
          params: toParams(props.params),
          children: () => props.children,
        })()
      ),
  };
  if (spec.children.length > 0) definition.children = spec.children;
  return definition;
};

export const browserHistory = () => solidBrowserHistory();
export const hashHistory = () => solidHashHistory();
export const memoryHistory = (url) => () => solidMemoryHistory(url);

export const createRouterImpl = (config) => {
  const options = { routes: config.routes };
  if (config.base != null) options.base = config.base;
  if (config.history != null) options.history = config.history;
  return solidCreateRouter(options);
};

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

export const useIsRoutingImpl = () => solidUseIsRouting();

export const useMatchImpl = (pattern) => {
  const match = solidUseMatch(() => pattern);
  return () => match() !== undefined;
};

export const useNavigateImpl = () => solidUseNavigate();

export const navigateImpl = (navigate, { to, options }) => {
  navigate(to, options);
};

export const goImpl = (navigate, delta) => {
  navigate(delta);
};
