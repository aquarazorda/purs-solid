// Transitional: @solidjs/router 2 replaces <Router>/<Route>/<A> with
// createRouter / defineRoute / plain links; the Phase 5 rewrite targets it.
// Namespace import keeps this module loadable.
import * as SolidRouter from "@solidjs/router";
import { createComponent } from "solid-js";

const solidA = SolidRouter.A;
const solidRoute = SolidRouter.Route;
const solidRouter = SolidRouter.Router;
const solidUseLocation = SolidRouter.useLocation;
const solidUseNavigate = SolidRouter.useNavigate;

export const router = (props) => (children) =>
  createComponent(solidRouter, {
    ...props,
    children,
  });

export const route = (props) => (children) =>
  createComponent(solidRoute, {
    ...props,
    children,
  });

export const link = (props) => (children) =>
  createComponent(solidA, {
    ...props,
    children,
  });

export const useLocationImpl = () =>
  solidUseLocation();

export const pathname = (location) => () =>
  location.pathname;

export const search = (location) => () =>
  location.search;

export const hash = (location) => () =>
  location.hash;

export const useNavigateImpl = () => {
  const navigate = solidUseNavigate();

  return {
    to: (to) => (options) => () => {
      navigate(to, options);
    },
    by: (delta) => () => {
      navigate(delta);
    },
  };
};
