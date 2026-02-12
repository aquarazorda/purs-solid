import { Base as solidBase, Link as solidLink, Meta as solidMeta, MetaProvider as solidMetaProvider, Style as solidStyle, Stylesheet as solidStylesheet, Title as solidTitle, useHead as solidUseHead } from "@solidjs/meta";
import { createComponent } from "solid-js/web";
import * as Data_Either from "../Data.Either/index.js";
import * as Data_Maybe from "../Data.Maybe/index.js";
import * as Data_Unit from "../Data.Unit/index.js";

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

const fallbackDataAttribute = "data-purs-solid-meta-id";

const normalizeChildren = (children) => {
  if (Array.isArray(children)) {
    return children.map((value) => String(value)).join("");
  }

  if (children == null) {
    return "";
  }

  return String(children);
};

const applyHeadFallback = (tagDescription) => {
  if (typeof document === "undefined" || document.head == null || tagDescription == null) {
    return;
  }

  const tagName = typeof tagDescription.tag === "string"
    ? tagDescription.tag.toLowerCase()
    : "";

  const props = tagDescription.props ?? {};

  if (tagName === "title") {
    document.title = normalizeChildren(props.children);
    return;
  }

  if (tagName === "") {
    return;
  }

  const markerValue = String(tagDescription.id ?? "");
  if (markerValue.length === 0) {
    return;
  }

  let element = document.head.querySelector(`[${fallbackDataAttribute}="${markerValue}"]`);

  if (element == null || element.tagName.toLowerCase() !== tagName) {
    element?.remove();
    element = document.createElement(tagName);
    element.setAttribute(fallbackDataAttribute, markerValue);
    document.head.appendChild(element);
  }

  for (const attributeName of element.getAttributeNames()) {
    if (attributeName !== fallbackDataAttribute) {
      element.removeAttribute(attributeName);
    }
  }

  for (const [key, value] of Object.entries(props)) {
    if (key === "children") {
      continue;
    }

    if (value == null || typeof value === "function") {
      continue;
    }

    element.setAttribute(key, String(value));
  }

  const childContent = normalizeChildren(props.children);
  if (childContent.length > 0) {
    element.textContent = childContent;
  } else {
    element.textContent = "";
  }
};

export const metaProvider = (props) => (children) =>
  createComponent(solidMetaProvider, {
    ...props,
    children,
  });

export const metaProviderWith = (props) => (renderChildren) =>
  createComponent(solidMetaProvider, {
    ...props,
    get children() {
      return renderChildren();
    },
  });

export const titleWithImpl = (props) => (value) =>
  createComponent(solidTitle, {
    ...props,
    children: value,
  });

export const titleFrom = (valueAccessor) =>
  createComponent(solidTitle, {
    get children() {
      return valueAccessor();
    },
  });

export const styleWithImpl = (props) => (value) =>
  createComponent(solidStyle, {
    ...props,
    children: value,
  });

export const meta = (props) =>
  createComponent(solidMeta, props);

export const link = (props) =>
  createComponent(solidLink, props);

export const base = (props) =>
  createComponent(solidBase, props);

export const stylesheet = (props) =>
  createComponent(solidStylesheet, props);

export const useHeadImpl = (tagDescription) => () => {
  try {
    solidUseHead({
      ...tagDescription,
      setting: fromMaybe(tagDescription.setting),
      name: fromMaybe(tagDescription.name),
    });

    return Data_Either.Right.create(Data_Unit.unit);
  } catch (error) {
    const message = toErrorMessage(error);
    if (message.includes("<MetaProvider /> should be in the tree")) {
      applyHeadFallback(tagDescription);
      return Data_Either.Right.create(Data_Unit.unit);
    }

    return Data_Either.Left.create(message);
  }
};
