import {
  children as solidChildren,
  createComponent,
  createMemo,
  Errored,
  For,
  Hydration,
  lazy as solidLazy,
  Loading,
  Match,
  NoHydration,
  Repeat,
  Reveal,
  Show,
  Switch,
} from "solid-js";
import {
  dynamic,
  isServer,
  MathMLElements,
  Namespaces,
  Portal,
  SVGElements,
} from "@solidjs/web";

class Reactive {
  constructor(read) {
    this.read = read;
  }
}

class Prerealized {
  constructor(value) {
    this.value = value;
  }
}

const realizeAll = (items) => {
  const out = new Array(items.length);
  for (let i = 0; i < items.length; i += 1) out[i] = realize(items[i]);
  return out;
};

// Reactive regions outside element children get a memo so errors reach the enclosing `Errored`.
export const realize = (jsx) => {
  if (typeof jsx === "function") return jsx();
  if (jsx instanceof Reactive) {
    const read = jsx.read;
    return createMemo(() => realize(read()), { sync: true });
  }
  if (Array.isArray(jsx)) return realizeAll(jsx);
  if (jsx instanceof Prerealized) return jsx.value;
  return jsx;
};

const realizeChild = (jsx) => {
  if (jsx instanceof Reactive) {
    const read = jsx.read;
    return () => realize(read());
  }
  return realize(jsx);
};

const realizeChildren = (children) => {
  if (children.length === 1) return realizeChild(children[0]);
  const out = new Array(children.length);
  for (let i = 0; i < children.length; i += 1) out[i] = realizeChild(children[i]);
  return out;
};

export const textJsx = (value) => value;

export const reactiveJsx = (read) => new Reactive(read);

export const textBindingImpl = (value) => (typeof value === "function" ? new Reactive(value) : value);

export const fragment = (items) => items;

export const empty = null;

const STATIC = 0;
const REACTIVE = 1;
const REF = 2;
const EVENT = 3;

export const staticPropImpl = (k, v) => ({ k, m: STATIC, v });

export const bindingPropImpl = (k, convert, v) =>
  typeof v === "function" ? { k, m: REACTIVE, v: () => convert(v()) } : { k, m: STATIC, v: convert(v) };

export const eventPropImpl = (k, handler) => ({ k, m: EVENT, v: (event) => handler(event)() });

export const refProp = (callback) => ({ k: "ref", m: REF, v: (element) => callback(element)() });

const readProp = (prop) => (prop.m === REACTIVE ? prop.v() : prop.v);

const mergeClasses = (classes) =>
  classes.length === 1 ? classes[0] : { k: "class", m: classes.some((c) => c.m === REACTIVE) ? REACTIVE : STATIC, v: null, classes };

const classValue = (entry) =>
  entry.classes === undefined ? readProp(entry) : entry.classes.map(readProp);

const staticComponents = new Map();

const staticComponent = (tag) => {
  let component = staticComponents.get(tag);
  if (component === undefined) {
    component = dynamic(() => tag, { static: true });
    staticComponents.set(tag, component);
  }
  return component;
};

const propsObject = (namespace, tag, props, children) => {
  // `xmlns` only for SVG / MathML tags that also exist in HTML (`a`, `title`, ...).
  const object = {};
  if (namespace === 1 && !SVGElements.has(tag)) object.xmlns = Namespaces.svg;
  else if (namespace === 2 && !MathMLElements.has(tag)) object.xmlns = Namespaces.mathml;
  let classes;
  let refs;

  for (let i = 0; i < props.length; i += 1) {
    const prop = props[i];
    if (prop.m === REF) (refs ??= []).push(prop.v);
    else if (prop.k === "class") (classes ??= []).push(prop);
    else if (prop.m === REACTIVE) Object.defineProperty(object, prop.k, { get: prop.v, enumerable: true });
    else if (prop.m === EVENT && isServer) continue;
    else object[prop.k] = prop.v;
  }

  if (classes !== undefined) {
    const entry = mergeClasses(classes);
    if (entry.m === REACTIVE) Object.defineProperty(object, "class", { get: () => classValue(entry), enumerable: true });
    else object.class = classValue(entry);
  }

  if (refs !== undefined && !isServer) object.ref = refs.length === 1 ? refs[0] : refs;

  if (children.length > 0) {
    Object.defineProperty(object, "children", { get: () => realizeChildren(children), enumerable: true });
  }

  return object;
};

export const elementImpl = (namespace, tag, props, children) => () =>
  createComponent(staticComponent(tag), propsObject(namespace, tag, props, children));

export const componentRep = (render) => (props) => realize(render(props)());

export const componentElement = (component, props) => () => createComponent(component, props);

export const propsComponentElement = (component, props, children) => () =>
  createComponent(component, propsObject(0, "", props, children));

// `undefined` values are left out so the component's defaults apply.
export const jsPropsComponentElement = (component, entries) => () => {
  const object = {};
  for (let i = 0; i < entries.length; i += 1) {
    const entry = entries[i];
    if (entry.get !== undefined) Object.defineProperty(object, entry.key, { get: entry.get, enumerable: true });
    else if (entry.value !== undefined) object[entry.key] = entry.value;
  }
  return createComponent(component, object);
};

// Falsy values inside a `Just` are boxed so `Show` / `Match` treat them as present.
class Falsy {
  constructor(value) {
    this.value = value;
  }
}

export const whenValue = (value) =>
  value === false || value === 0 || value === "" || value == null || Number.isNaN(value) ? new Falsy(value) : value;

const fromWhen = (value) => (value instanceof Falsy ? value.value : value);

export const showImpl = (condition, fallback, content) => () =>
  createComponent(Show, {
    get when() {
      return condition();
    },
    get fallback() {
      return realize(fallback);
    },
    get children() {
      return realize(content);
    },
  });

export const showMaybeImpl = (keyed, condition, fallback, render) => () =>
  createComponent(Show, {
    get when() {
      return condition();
    },
    keyed,
    get fallback() {
      return realize(fallback);
    },
    children: keyed
      ? (value) => realize(render(fromWhen(value))())
      : (value) => realize(render(() => fromWhen(value()))()),
  });

export const keyedByIdentity = true;

export const keyedByPosition = false;

export const forImpl = (keyed, each, fallback, render) => () =>
  createComponent(For, {
    get each() {
      return each();
    },
    keyed,
    get fallback() {
      return realize(fallback);
    },
    children: (item, index) => realize(render(item)(index)()),
  });

export const repeatImpl = (count, fallback, render) => () =>
  createComponent(Repeat, {
    get count() {
      return count();
    },
    get fallback() {
      return realize(fallback);
    },
    children: (index) => realize(render(index)()),
  });

export const switchImpl = (cases, fallback) => () =>
  createComponent(Switch, {
    get fallback() {
      return realize(fallback);
    },
    get children() {
      return realize(cases);
    },
  });

export const matchImpl = (condition, content) => () =>
  createComponent(Match, {
    get when() {
      return condition();
    },
    get children() {
      return realize(content);
    },
  });

export const matchMaybeImpl = (condition, render) => () =>
  createComponent(Match, {
    get when() {
      return condition();
    },
    keyed: true,
    children: (value) => realize(render(fromWhen(value))()),
  });

export const loadingImpl = (fallback, content) => () =>
  createComponent(Loading, {
    get fallback() {
      return realize(fallback);
    },
    get children() {
      return realize(content);
    },
  });

const toError = (error) => (error instanceof Error ? error : new Error(String(error)));

export const erroredImpl = (renderFallback, content) => () =>
  createComponent(Errored, {
    fallback: (error, reset) => realize(renderFallback(() => toError(error()))(() => reset())()),
    get children() {
      return realize(content);
    },
  });

export const revealImpl = (options, items) => () =>
  createComponent(Reveal, {
    ...options,
    get children() {
      return realize(items);
    },
  });

export const portalImpl = (mount, content) => () =>
  createComponent(Portal, {
    mount: mount ?? undefined,
    get children() {
      return realize(content);
    },
  });

export const dynamicImpl = (source, props) => () => {
  const Component = dynamic(() => source());
  return createComponent(Component, props);
};

export const noHydrationImpl = (content) => () =>
  createComponent(NoHydration, {
    get children() {
      return realize(content);
    },
  });

export const hydrationImpl = (content) => () =>
  createComponent(Hydration, {
    get children() {
      return realize(content);
    },
  });

export const provideImpl = (context, value, children) => () =>
  createComponent(context, {
    value: { value },
    get children() {
      return realize(children());
    },
  });

export const childrenImpl = (resolve) => {
  const resolved = solidChildren(() => realize(resolve()));
  return () => new Prerealized(resolved());
};

export const lazyImpl = (exportName, load) => solidLazy(() => load(), { export: exportName });

export const preloadImpl = (component) => {
  component.preload?.().catch(() => {});
};
