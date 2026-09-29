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
    return createMemo(() => realize(read()), { sync: true });
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

// Elements go through Solid's public `dynamic(() => tag, { static: true })`:
// Solid creates (or, when hydrating, claims) the element and applies props
// with `spread`, on the client and on the server. Reactive props are getters,
// and children are a getter so they're created after their parent.
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
  // Solid picks the namespace for known SVG / MathML tags; `xmlns` is only
  // needed for tags that also exist in HTML (`a`, `title`, `script`, `style`).
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
