import {
  children as solidChildren,
  createComponent,
  createMemo,
  Errored,
  For,
  Hydration,
  isHydrating,
  lazy as solidLazy,
  Loading,
  Match,
  NoHydration,
  Repeat,
  Reveal,
  Show,
  Switch,
  untrack,
} from "solid-js";
import {
  assign,
  clientOnly as solidClientOnly,
  dynamic,
  insert,
  isServer,
  Namespaces,
  Portal,
  spread,
  SVGElements,
  template,
  VoidElements,
} from "@solidjs/web";

class Reactive {
  constructor(read) {
    this.read = read;
  }
}

class El {
  constructor(ns, tag, props, children) {
    this.ns = ns;
    this.tag = tag;
    this.props = props;
    this.children = children;
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
  if (jsx instanceof El) return realizeElement(jsx);
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

// Used by templates compiled from PureScript (`vite/compile.mjs`): a child to
// insert, a field's value (from a value or an accessor), and a field Solid's
// compiler can't express, as props to spread.
export const childValue = (jsx) => untrack(() => realizeChild(jsx));

export const readValue = (value) => (typeof value === "function" ? value() : value);

export const fieldValue = (value, convert) => convert(typeof value === "function" ? value() : value);

export const fieldProps = (entry, value) => propsObject(0, "", [entry(value)], noChildren);

export const textJsx = (value) => value;

export const reactiveJsx = (read) => new Reactive(read);

export const textBindingImpl = (value) => (typeof value === "function" ? new Reactive(value) : value);

export const fragment = (items) => items;

export const empty = null;

const STATIC = 0;
const REACTIVE = 1;
const REF = 2;
const EVENT = 3;
const PROPS = 4;

export const bindingPropImpl = (k, convert, v) =>
  typeof v === "function" ? { k, m: REACTIVE, v: () => convert(v()) } : { k, m: STATIC, v: convert(v) };

export const eventPropImpl = (k, handler) => ({ k, m: EVENT, v: (event) => handler(event)() });

export const refProp = (callback) => ({ k: "ref", m: REF, v: (element) => callback(element)() });

export const propsProp = (props) => ({ k: "", m: PROPS, v: props });

const readProp = (prop) => (prop.m === REACTIVE ? prop.v() : prop.v);

// Several `class` (or `style`) props on one element become one value.
const mergeEntries = (k, entries) =>
  entries.length === 1 ? entries[0] : { k, m: entries.some((e) => e.m === REACTIVE) ? REACTIVE : STATIC, v: null, entries };

const classValue = (entry) =>
  entry.entries === undefined ? readProp(entry) : entry.entries.map(readProp);

const cssText = (value) =>
  typeof value === "string" ? value : Object.entries(value).map(([k, v]) => `${k}: ${v}`).join("; ");

const styleValue = (entry) => {
  if (entry.entries === undefined) return readProp(entry);
  const values = entry.entries.map(readProp);
  return values.every((v) => typeof v === "object") ? Object.assign({}, ...values) : values.map(cssText).join("; ");
};

const defineMerged = (object, k, entries, read) => {
  const entry = mergeEntries(k, entries);
  if (entry.m === REACTIVE) {
    reactiveProps = true;
    Object.defineProperty(object, k, { get: () => read(entry), enumerable: true });
  }
  else object[k] = read(entry);
};

const staticComponents = new Map();

const staticComponent = (tag) => {
  let component = staticComponents.get(tag);
  if (component === undefined) {
    component = dynamic(() => tag, { static: true });
    staticComponents.set(tag, component);
  }
  return component;
};

// Whether the last `propsObject` defined a getter (a reactive prop).
let reactiveProps = false;

const propsObject = (namespace, tag, props, children) => {
  // `xmlns` only for SVG tags that also exist in HTML (`a`, `title`, ...).
  const object = {};
  reactiveProps = false;
  if (namespace === 1 && !SVGElements.has(tag)) object.xmlns = Namespaces.svg;
  let classes;
  let styles;
  let refs;

  const add = (props) => {
    for (let i = 0; i < props.length; i += 1) {
      const prop = props[i];
      if (prop.m === PROPS) add(prop.v);
      else if (prop.m === REF) (refs ??= []).push(prop.v);
      else if (prop.k === "class") (classes ??= []).push(prop);
      else if (prop.k === "style") (styles ??= []).push(prop);
      else if (prop.m === REACTIVE) {
        reactiveProps = true;
        Object.defineProperty(object, prop.k, { get: prop.v, enumerable: true });
      }
      else if (prop.m === EVENT && isServer) continue;
      else object[prop.k] = prop.v;
    }
  };
  add(props);

  if (classes !== undefined) defineMerged(object, "class", classes, classValue);
  if (styles !== undefined) defineMerged(object, "style", styles, styleValue);

  if (refs !== undefined && !isServer) object.ref = refs.length === 1 ? refs[0] : refs;

  // Static children as a plain value let `spread` insert them without an effect.
  if (children.length > 0) {
    if (children.some((child) => child instanceof Reactive)) {
      Object.defineProperty(object, "children", { get: () => realizeChildren(children), enumerable: true });
    } else object.children = realizeChildren(children);
  }

  return object;
};

export const elementImpl = (namespace, tag, props, children) => new El(namespace, tag, props, children);

// The server and hydration create (or claim) each element through Solid's
// `dynamic`. New DOM in the browser clones one template per subtree shape
// instead, then applies each element's props and inserts its other children.
const realizeElement = (el) =>
  isServer || isHydrating() || !templatable(el.tag)
    ? createComponent(staticComponent(el.tag), propsObject(el.ns, el.tag, el.props, el.children))
    : untrack(() => cloneElement(el));

const untemplatable = new Set(["html", "head", "body", "template"]);
const templatable = (tag) => !untemplatable.has(tag) && !tag.includes("-");

const inTemplate = (child, ns) =>
  child instanceof El && templatable(child.tag) && (child.ns === ns || (ns === 0 && child.tag === "svg"));

const shapeKey = (el) => {
  let key = el.tag + "(";
  for (const child of el.children) if (inTemplate(child, el.ns)) key += shapeKey(child);
  return key + ")";
};

const markup = (el) => {
  if (VoidElements.has(el.tag)) return `<${el.tag}>`;
  let html = `<${el.tag}>`;
  for (const child of el.children) if (inTemplate(child, el.ns)) html += markup(child);
  return html + `</${el.tag}>`;
};

const templates = new Map();

const cloneElement = (el) => {
  const key = el.ns + shapeKey(el);
  let make = templates.get(key);
  if (make === undefined) {
    make = el.ns === 1 && el.tag !== "svg" ? template(`<svg>${markup(el)}</svg>`, 2) : template(markup(el));
    templates.set(key, make);
  }
  const node = make();
  fill(node, el);
  return node;
};

const noChildren = [];

const fill = (node, el) => {
  if (el.props.length > 0) {
    const props = propsObject(el.ns, el.tag, el.props, noChildren);
    delete props.xmlns;
    if (reactiveProps) spread(node, props, true);
    else assign(node, props, true);
  }
  const children = el.children;
  if (children.length === 0) return;
  // Elements are already in the clone and static text goes in next to them.
  // Each run of other children is inserted together, as one array, before
  // the static node that follows it.
  const anchors = new Array(children.length);
  let element = node.firstChild;
  for (let i = 0; i < children.length; i += 1) {
    const child = children[i];
    if (inTemplate(child, el.ns)) {
      fill(element, child);
      anchors[i] = element;
      element = element.nextSibling;
    } else if (typeof child === "string" || typeof child === "number") {
      anchors[i] = node.insertBefore(document.createTextNode(child), element);
    }
  }
  for (let start = 0; start < children.length; ) {
    if (anchors[start] !== undefined) {
      start += 1;
      continue;
    }
    let end = start;
    while (end < children.length && anchors[end] === undefined) end += 1;
    const marker = end < children.length ? anchors[end] : null;
    const run = children.slice(start, end).map(realizeChild);
    const value = run.length === 1 ? run[0] : run.some((child) => typeof child === "function") ? () => run : run;
    if (start === 0 && end === children.length) insert(node, value);
    else insert(node, value, marker);
    start = end;
  }
};

// Marks the values `lazy` may load: a loaded export without it isn't a component.
const componentTag = Symbol.for("purs-solid/component");
const tagged = (component) => Object.assign(component, { [componentTag]: true });

export const componentRep = (render) => tagged((props) => realize(render(props)()));

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

export const loadingImpl = (key, fallback, content) => () => {
  const props = {
    get fallback() {
      return realize(fallback);
    },
    get children() {
      return realize(content);
    },
  };
  if (key !== null) Object.defineProperty(props, "on", { get: () => key(), enumerable: true });
  return createComponent(Loading, props);
};

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

export const childrenArrayImpl = (resolve) => {
  const resolved = solidChildren(() => realize(resolve()));
  return () => resolved.toArray().map((child) => new Prerealized(child));
};

// purs-solid/vite registers each lazily loaded module; unbundled, modules load
// from next to this one. The specifier is a variable so that bundlers don't
// read it as a pattern matching every compiled module.
const lazyModules = new Map();

export const registerLazyModule = (name, load) => {
  lazyModules.set(name, load);
};

const importCompiled = (name) => {
  const specifier = `../${name}/index.js`;
  return import(/* @vite-ignore */ specifier);
};

export const loadModule = (name) => () => (lazyModules.get(name) ?? importCompiled)(name);

const loadComponent = (moduleName, exportName, load) => () =>
  load().then((module) => {
    if (module[exportName]?.[componentTag] !== true) {
      throw new Error(`purs-solid: ${moduleName}.${exportName} is loaded lazily, but it isn't a component`);
    }
    return module;
  });

export const lazyImpl = (moduleName, exportName, load) =>
  tagged(solidLazy(loadComponent(moduleName, exportName, load), { export: exportName }));

export const clientOnlyImpl = (moduleName, exportName, load) => {
  const component = solidClientOnly(loadComponent(moduleName, exportName, load), { export: exportName, lazy: true });
  return tagged((props) =>
    component({
      ...props,
      get fallback() {
        return realize(props.fallback);
      },
    })
  );
};

export const preloadImpl = (component) => {
  component.preload?.().catch(() => {});
};
