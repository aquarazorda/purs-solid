import { A as solidA, Route as solidRoute, Router as solidRouter, useLocation as solidUseLocation, useNavigate as solidUseNavigate } from "@solidjs/router";
import { createComponent } from "solid-js/web";
import * as Data_Either from "../Data.Either/index.js";

const toErrorMessage = (error) => {
  if (typeof error === "string") {
    return error;
  }

  if (error instanceof Error && typeof error.message === "string") {
    return error.message;
  }

  return String(error);
};

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

export const useLocationImpl = () => {
  try {
    return Data_Either.Right.create(solidUseLocation());
  } catch (error) {
    return Data_Either.Left.create(toErrorMessage(error));
  }
};

export const pathname = (location) => () =>
  location.pathname;

export const search = (location) => () =>
  location.search;

export const hash = (location) => () =>
  location.hash;

export const useNavigateImpl = () => {
  try {
    const navigate = solidUseNavigate();
    return Data_Either.Right.create((to) => (options) => () => {
      navigate(to, options);
    });
  } catch (error) {
    return Data_Either.Left.create(toErrorMessage(error));
  }
};

export const navigateBy = (navigateTo) => (delta) => () => {
  navigateTo(delta, undefined);
};
