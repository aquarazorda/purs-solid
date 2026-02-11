import {
  createComponent,
  Dynamic as solidDynamic,
  ErrorBoundary as solidErrorBoundary,
  For as solidFor,
  Index as solidIndex,
  Match as solidMatch,
  NoHydration as solidNoHydration,
  Portal as solidPortal,
  Show as solidShow,
  Suspense as solidSuspense,
  SuspenseList as solidSuspenseList,
  Switch as solidSwitch,
} from "solid-js/web";
import * as Data_Maybe from "../Data.Maybe/index.js";

const fromMaybe = (maybeValue) =>
  maybeValue instanceof Data_Maybe.Just
    ? maybeValue.value0
    : undefined;

const toErrorMessage = (error) => {
  if (typeof error === "string") {
    return error;
  }

  if (error instanceof Error && typeof error.message === "string") {
    return error.message;
  }

  return String(error);
};

export const whenElseImpl = (condition) => (fallback) => (content) =>
  createComponent(solidShow, {
    get when() {
      return condition();
    },
    fallback,
    children: content,
  });

export const whenElseKeyedImpl = (condition) => (fallback) => (content) =>
  createComponent(solidShow, {
    get when() {
      return condition();
    },
    keyed: true,
    fallback,
    children: content,
  });

export const showMaybeElseImpl = (condition) => (fallback) => (render) =>
  createComponent(solidShow, {
    get when() {
      return fromMaybe(condition());
    },
    fallback,
    children: (valueAccessor) => render(() => valueAccessor())(),
  });

export const showMaybeKeyedElseImpl = (condition) => (fallback) => (render) =>
  createComponent(solidShow, {
    get when() {
      return fromMaybe(condition());
    },
    keyed: true,
    fallback,
    children: (value) => render(value)(),
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

export const matchMaybe = (condition) => (render) =>
  createComponent(solidMatch, {
    get when() {
      return fromMaybe(condition());
    },
    children: (value) => render(value)(),
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

export const errorBoundaryImpl = (fallback) => (content) =>
  createComponent(solidErrorBoundary, {
    fallback,
    children: content,
  });

export const errorBoundaryWithImpl = (renderFallback) => (content) =>
  createComponent(solidErrorBoundary, {
    fallback: (error, reset) => renderFallback(toErrorMessage(error))(() => reset())(),
    children: content,
  });

export const noHydrationImpl = (content) =>
  createComponent(solidNoHydration, {
    children: content,
  });

export const suspenseImpl = (fallback) => (content) =>
  createComponent(solidSuspense, {
    fallback,
    children: content,
  });

export const suspenseListImpl = (revealOrder) => (tail) => (children) =>
  createComponent(solidSuspenseList, {
    revealOrder,
    tail: fromMaybe(tail),
    children,
  });

export const portalWithImpl = (maybeMount) => (useShadow) => (isSVG) => (content) =>
  createComponent(solidPortal, {
    mount: fromMaybe(maybeMount),
    useShadow,
    isSVG,
    children: content,
  });
