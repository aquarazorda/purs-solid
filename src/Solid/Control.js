// Transitional mapping onto Solid 2 components; the Phase 3 redesign renames the
// PureScript API (suspense -> loading, errorBoundary -> errored, ...).
import {
  createComponent,
  Errored as solidErrored,
  For as solidFor,
  Loading as solidLoading,
  Match as solidMatch,
  NoHydration as solidNoHydration,
  Reveal as solidReveal,
  Show as solidShow,
  Switch as solidSwitch,
} from "solid-js";
import { Dynamic as solidDynamic, Portal as solidPortal } from "@solidjs/web";
// `Maybe` values are converted by the PureScript side: functions taking a `toNullable`
// argument receive `Data.Nullable.toNullable`, and plain options arrive already nullable.
const fromNullable = (value) =>
  value == null ? undefined : value;

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

export const showMaybeElseImpl = (toNullable) => (condition) => (fallback) => (render) =>
  createComponent(solidShow, {
    get when() {
      return fromNullable(toNullable(condition()));
    },
    fallback,
    children: (valueAccessor) => render(() => valueAccessor())(),
  });

export const showMaybeKeyedElseImpl = (toNullable) => (condition) => (fallback) => (render) =>
  createComponent(solidShow, {
    get when() {
      return fromNullable(toNullable(condition()));
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
  createComponent(solidFor, {
    get each() {
      return each();
    },
    keyed: false,
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

export const matchMaybeImpl = (toNullable) => (condition) => (render) =>
  createComponent(solidMatch, {
    get when() {
      return fromNullable(toNullable(condition()));
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
  createComponent(solidErrored, {
    fallback,
    children: content,
  });

export const errorBoundaryWithImpl = (renderFallback) => (content) =>
  createComponent(solidErrored, {
    fallback: (error, reset) => renderFallback(toErrorMessage(error()))(() => reset())(),
    children: content,
  });

export const noHydrationImpl = (content) =>
  createComponent(solidNoHydration, {
    children: content,
  });

export const suspenseImpl = (fallback) => (content) =>
  createComponent(solidLoading, {
    fallback,
    children: content,
  });

// Solid 2's Reveal has `order` ("sequential" | "together" | "natural") and
// `collapsed`; "backwards" has no equivalent and falls back to "sequential".
export const suspenseListImpl = (revealOrder) => (tail) => (children) =>
  createComponent(solidReveal, {
    order: revealOrder === "together" ? "together" : "sequential",
    collapsed: fromNullable(tail) === "collapsed",
    children,
  });

// Solid 2's Portal only takes `mount`; `useShadow` / `isSVG` are ignored.
export const portalWithImpl = (maybeMount) => (_useShadow) => (_isSVG) => (content) =>
  createComponent(solidPortal, {
    mount: fromNullable(maybeMount),
    children: content,
  });
