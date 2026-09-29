import {
  children as solidChildren,
  createComponent,
  Errored,
  For,
  Hydration,
  lazy as solidLazy,
  Loading,
  Match,
  NoHydration,
  Repeat,
  Reveal,
  sharedConfig,
  Show,
  Switch,
} from "solid-js";
import {
  assign,
  dynamic,
  effect,
  getNextElement,
  insert,
  isServer,
  memo,
  Namespaces,
  Portal,
  ref as solidRef,
  runHydrationEvents,
  ssrElement,
} from "@solidjs/web";

// ---------------------------------------------------------------------------
// JSX representation
//
//   string      text
//   null        nothing
//   Array       fragment
//   function    lazy node: calling it creates the node (already realized)
//   Reactive    reactive region: `read` yields JSX, re-rendered on change
//
// `realize` turns a description into what Solid's `insert` understands. Lazy
// nodes are called; reactive regions become functions, which Solid tracks.

class Reactive {
  constructor(read) {
    this.read = read;
  }
}

// Content that is already realized (e.g. resolved by `children`).
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

// A reactive region anywhere but directly inside an element (a component's
// result, a control-flow branch, a fragment) is wrapped in a memo, as compiled
// Solid does for top-level expressions. The memo is owned by the current
// scope, so errors reach the enclosing `Errored` and cleanup follows the owner.
// Consumers such as a parent's `insert` would otherwise evaluate a bare
// function in *their* scope.
export const realize = (jsx) => {
  if (typeof jsx === "function") return jsx();
  if (jsx instanceof Reactive) {
    const read = jsx.read;
    return memo(() => realize(read()));
  }
  if (Array.isArray(jsx)) return realizeAll(jsx);
  if (jsx instanceof Prerealized) return jsx.value;
  return jsx;
};

// Directly inside an element, the element's own `insert` effect (created in
// the current scope) tracks the region, so no extra memo is needed.
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

export const fragment = (items) => items;

export const empty = null;

// ---------------------------------------------------------------------------
// Props: `{ k: name, m: mode, v: value }`.

const STATIC = 0;
const REACTIVE = 1;
const REF = 2;
const EVENT = 3;

export const staticPropImpl = (k, v) => ({ k, m: STATIC, v });

export const reactivePropImpl = (k, v) => ({ k, m: REACTIVE, v });

export const eventPropImpl = (k, handler) => ({ k, m: EVENT, v: (event) => handler(event)() });

export const refProp = (callback) => ({ k: "ref", m: REF, v: (element) => callback(element)() });

const readProp = (prop) => (prop.m === REACTIVE ? prop.v() : prop.v);

// Several `class` props merge into one array value (Solid's `class` accepts
// strings, `{ name: boolean }` objects and arrays of them).
const mergeClasses = (classes) =>
  classes.length === 1 ? classes[0] : { k: "class", m: classes.some((c) => c.m === REACTIVE) ? REACTIVE : STATIC, v: null, classes };

const classValue = (entry) =>
  entry.classes === undefined ? readProp(entry) : entry.classes.map(readProp);

// Client: static props are assigned once (no computation); reactive props
// share one render effect per element, and `assign` diffs against the
// previous values. Elements with only static props create no computations.
const applyProps = (node, props) => {
  let statics;
  let reactives;
  let refs;
  let classes;

  for (let i = 0; i < props.length; i += 1) {
    const prop = props[i];
    if (prop.m === REF) (refs ??= []).push(prop.v);
    else if (prop.k === "class") (classes ??= []).push(prop);
    else if (prop.m === REACTIVE) (reactives ??= []).push(prop);
    else (statics ??= {})[prop.k] = prop.v;
  }

  if (classes !== undefined) {
    const entry = mergeClasses(classes);
    if (entry.m === REACTIVE) (reactives ??= []).push({ k: "class", m: REACTIVE, v: () => classValue(entry) });
    else (statics ??= {}).class = classValue(entry);
  }

  if (statics !== undefined) assign(node, statics, true, {}, true);

  if (reactives !== undefined) {
    const previous = {};
    effect(
      () => {
        const next = {};
        for (let i = 0; i < reactives.length; i += 1) next[reactives[i].k] = reactives[i].v();
        return next;
      },
      (next) => {
        assign(node, next, true, previous, true);
      }
    );
  }

  if (refs !== undefined) {
    for (let i = 0; i < refs.length; i += 1) {
      const callback = refs[i];
      solidRef(() => callback, node);
    }
  }
};

const createNode = (namespace, tag) =>
  namespace === 0
    ? document.createElement(tag)
    : document.createElementNS(namespace === 1 ? Namespaces.svg : Namespaces.mathml, tag);

// The element is created (or claimed, when hydrating) before its children, in
// the same order the server assigns hydration keys.
const clientElement = (namespace, tag, props, children) => {
  const hydrating = sharedConfig.hydrating;
  const node = hydrating ? getNextElement() : createNode(namespace, tag);
  if (props.length > 0) applyProps(node, props);
  if (hydrating) runHydrationEvents();
  if (children.length > 0) insert(node, realizeChildren(children));
  return node;
};

// Server: `ssrElement` reads props once; events and refs don't render.
// Children are a getter so they render after the element's hydration key.
const serverElement = (tag, props, children) => {
  const object = {};
  let classes;

  for (let i = 0; i < props.length; i += 1) {
    const prop = props[i];
    if (prop.m === REF || prop.m === EVENT) continue;
    if (prop.k === "class") (classes ??= []).push(prop);
    else if (prop.m === REACTIVE) Object.defineProperty(object, prop.k, { get: prop.v, enumerable: true });
    else object[prop.k] = prop.v;
  }

  if (classes !== undefined) {
    const entry = mergeClasses(classes);
    Object.defineProperty(object, "class", { get: () => classValue(entry), enumerable: true });
  }

  if (children.length > 0) {
    Object.defineProperty(object, "children", { get: () => realizeChildren(children), enumerable: true });
  }

  return ssrElement(tag, object, undefined, true);
};

export const elementImpl = (namespace, tag, props, children) => () =>
  isServer ? serverElement(tag, props, children) : clientElement(namespace, tag, props, children);

// ---------------------------------------------------------------------------
// Components

export const componentRep = (render) => (props) => realize(render(props)());

export const componentElement = (component, props) => () => createComponent(component, props);

// ---------------------------------------------------------------------------
// Control flow. Content is passed through getters, so Solid creates it only
// when (and each time) it's shown.

// `Show` / `Match` test truthiness; falsy PureScript values inside a `Just`
// are boxed so they still count as present.
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

export const showMaybeImpl = (condition, fallback, render) => () =>
  createComponent(Show, {
    get when() {
      return condition();
    },
    get fallback() {
      return realize(fallback);
    },
    children: (value) => realize(render(() => fromWhen(value()))()),
  });

export const showMaybeKeyedImpl = (condition, fallback, render) => () =>
  createComponent(Show, {
    get when() {
      return condition();
    },
    keyed: true,
    get fallback() {
      return realize(fallback);
    },
    children: (value) => realize(render(fromWhen(value))()),
  });

export const forImpl = (each, fallback, render) => () =>
  createComponent(For, {
    get each() {
      return each();
    },
    get fallback() {
      return realize(fallback);
    },
    children: (item, index) => realize(render(item)(index)()),
  });

export const forUnkeyedImpl = (each, fallback, render) => () =>
  createComponent(For, {
    get each() {
      return each();
    },
    keyed: false,
    get fallback() {
      return realize(fallback);
    },
    children: (item, index) => realize(render(item)(index)()),
  });

export const forByImpl = (key, each, fallback, render) => () =>
  createComponent(For, {
    get each() {
      return each();
    },
    keyed: (item) => key(item),
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

export const revealImpl = (order, collapsed, items) => () =>
  createComponent(Reveal, {
    order,
    collapsed,
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
    value,
    get children() {
      return realize(children());
    },
  });

export const childrenImpl = (resolve) => {
  const resolved = solidChildren(() => realize(resolve()));
  return () => new Prerealized(resolved());
};

export const lazyImpl = (load) =>
  solidLazy(() => load().then((component) => ({ default: component })));
