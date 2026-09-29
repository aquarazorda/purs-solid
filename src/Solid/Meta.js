import { Base as solidBase, Link as solidLink, Meta as solidMeta, MetaProvider as solidMetaProvider, Style as solidStyle, Stylesheet as solidStylesheet, Title as solidTitle, useHead as solidUseHead } from "@solidjs/meta";
import { createComponent } from "solid-js/web";

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

// `setting` and `name` arrive as nullable values (converted on the PureScript side).
export const useHeadImpl = (tagDescription) => {
  const description = {
    ...tagDescription,
    setting: tagDescription.setting ?? undefined,
    name: tagDescription.name ?? undefined,
  };

  try {
    solidUseHead(description);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    if (!message.includes("<MetaProvider /> should be in the tree")) {
      throw error;
    }

    applyHeadFallback(description);
  }
};
