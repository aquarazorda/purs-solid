import {
  createComponent,
  Dynamic as solidDynamic,
  For as solidFor,
  Index as solidIndex,
  Match as solidMatch,
  Portal as solidPortal,
  Show as solidShow,
  Switch as solidSwitch,
} from "solid-js/web";
import * as Data_Maybe from "../Data.Maybe/index.js";

const fromMaybe = (maybeValue) =>
  maybeValue instanceof Data_Maybe.Just
    ? maybeValue.value0
    : undefined;

export const whenElseImpl = (condition) => (fallback) => (content) =>
  createComponent(solidShow, {
    get when() {
      return condition();
    },
    fallback,
    children: content,
  });

export const forEachElseImpl = (each) => (fallback) => (render) =>
  createComponent(solidFor, {
    get each() {
      return each();
    },
    fallback,
    children: (item) => render(item)(),
  });

export const forEachWithIndexElseImpl = (each) => (fallback) => (render) =>
  createComponent(solidFor, {
    get each() {
      return each();
    },
    fallback,
    children: (item, indexAccessor) => render(item)(indexAccessor)(),
  });

export const indexEachElseImpl = (each) => (fallback) => (render) =>
  createComponent(solidIndex, {
    get each() {
      return each();
    },
    fallback,
    children: (itemAccessor) => render(itemAccessor)(),
  });

export const matchWhen = (condition) => (content) =>
  createComponent(solidMatch, {
    get when() {
      return condition();
    },
    children: content,
  });

export const matchWhenKeyed = (condition) => (content) =>
  createComponent(solidMatch, {
    get when() {
      return condition();
    },
    keyed: true,
    children: content,
  });

export const switchCasesElseImpl = (fallback) => (cases) =>
  createComponent(solidSwitch, {
    fallback,
    children: cases,
  });

export const dynamicTag = (tag) => (props) =>
  createComponent(solidDynamic, {
    component: tag,
    ...props,
  });

export const dynamicComponent = (component) => (props) =>
  createComponent(solidDynamic, {
    component,
    ...props,
  });

export const portalAtImpl = (maybeMount) => (content) =>
  createComponent(solidPortal, {
    mount: fromMaybe(maybeMount),
    children: content,
  });
