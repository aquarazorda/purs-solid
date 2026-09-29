import { A as solidA, Route as solidRoute, Router as solidRouter, useLocation as solidUseLocation, useNavigate as solidUseNavigate } from "@solidjs/router";
import { createComponent } from "solid-js/web";

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
