import {
  $PROXY,
  affects as solidAffects,
  createOptimisticStore as solidCreateOptimisticStore,
  createProjection as solidCreateProjection,
  createStore as solidCreateStore,
  deep as solidDeep,
  isWrappable as solidIsWrappable,
  reconcile as solidReconcile,
  snapshot as solidSnapshot,
} from "solid-js";

const runPreparer = (prepare, value) => {
  if (prepare !== null) prepare(value);
};

const isProxy = (node) =>
  node !== null && typeof node === "object" && node[$PROXY] !== undefined;

const plain = (node) => (isProxy(node) ? solidSnapshot(node) : node);

export const createStoreImpl = (prepare, initial) => {
  runPreparer(prepare, initial);
  const [store, setter] = solidCreateStore(initial);
  return { store: () => store, setter };
};

export const focusImpl = (keys) => (cursor) => {
  if (keys.length === 0) return cursor;
  return () => {
    let node = cursor();
    for (const k of keys) node = node[k];
    return node;
  };
};

export const value = (cursor) => () => {
  const node = cursor();
  return isProxy(node) ? solidDeep(node) : node;
};

const itemCursors = new WeakMap();

const itemCursor = (element) => {
  let cursor = itemCursors.get(element);
  if (cursor === undefined) {
    cursor = () => element;
    itemCursors.set(element, cursor);
  }
  return cursor;
};

export const itemsImpl = (cursor) => () => {
  const array = cursor();
  const out = new Array(array.length);
  for (let i = 0; i < array.length; i += 1) out[i] = itemCursor(array[i]);
  return out;
};

export const snapshot = (cursor) => () => plain(cursor());

const replaceContents = (draft, next) => {
  if (Array.isArray(draft)) {
    draft.length = next.length;
    for (let i = 0; i < next.length; i += 1) draft[i] = next[i];
    return;
  }
  for (const k of Object.keys(draft)) {
    if (!(k in next)) delete draft[k];
  }
  for (const k of Object.keys(next)) draft[k] = next[k];
};

const rootRef = (draft) => ({
  get: () => draft,
  set: (next) => replaceContents(draft, next),
});

const childRef = (parent, k) => ({
  get: () => parent.get()[k],
  set: (next) => {
    parent.get()[k] = next;
  },
});

export const appendUpdate = (first) => (second) => (ref) => {
  first(ref);
  second(ref);
};

export const emptyUpdate = () => {};

export const updateImpl = (setter, change) => {
  setter((draft) => {
    change(rootRef(draft));
  });
};

export const atImpl = (keys) => (change) => (ref) => {
  let target = ref;
  for (const k of keys) target = childRef(target, k);
  change(target);
};

export const setImpl = (prepare) => (next) => (ref) => {
  runPreparer(prepare, next);
  ref.set(next);
};

export const modifyImpl = (prepare) => (f) => (ref) => {
  const next = f(plain(ref.get()));
  runPreparer(prepare, next);
  ref.set(next);
};

export const pushImpl = (prepare) => (element) => (ref) => {
  runPreparer(prepare, element);
  ref.get().push(element);
};

// Predicates see draft proxies; atomic fields are frozen, so matching works.
export const filter = (keep) => (ref) => {
  const array = ref.get();
  for (let i = array.length - 1; i >= 0; i -= 1) {
    if (!keep(array[i])) array.splice(i, 1);
  }
};

export const atIndex = (index) => (change) => (ref) => {
  const array = ref.get();
  if (index >= 0 && index < array.length) change(childRef(ref, index));
};

export const each = (change) => (ref) => {
  const array = ref.get();
  for (let i = 0; i < array.length; i += 1) change(childRef(ref, i));
};

export const eachWhere = (predicate) => (change) => (ref) => {
  const array = ref.get();
  for (let i = 0; i < array.length; i += 1) {
    if (predicate(array[i])) change(childRef(ref, i));
  }
};

const reconcileWith = (prepare, next, key) => (ref) => {
  runPreparer(prepare, next);
  const current = ref.get();
  if (isProxy(current) && solidIsWrappable(next)) solidReconcile(next, key)(current);
  else ref.set(next);
};

export const reconcileImpl = (prepare) => (next) => reconcileWith(prepare, next, undefined);

export const reconcileByImpl = (prepare) => (toKey) => (next) =>
  reconcileWith(prepare, next, (item) => toKey(item));

export const createProjectionImpl = (prepare, compute, seed) => {
  runPreparer(prepare, seed);
  const store = solidCreateProjection((draft) => {
    compute()(rootRef(draft));
  }, seed);
  return () => store;
};

export const createSelectorImpl = (toKey, source) => {
  let previous;
  const selected = solidCreateProjection((draft) => {
    const next = toKey(source());
    if (previous !== undefined && previous !== next) delete draft[previous];
    draft[next] = true;
    previous = next;
  }, {});
  return (candidate) => () => selected[toKey(candidate)] === true;
};

export const createOptimisticStoreImpl = (prepare, initial) => {
  runPreparer(prepare, initial);
  const [store, setter] = solidCreateOptimisticStore(initial);
  return { store: () => store, setter };
};

export const createOptimisticProjectionImpl = (prepare, compute, seed) => {
  runPreparer(prepare, seed);
  const [store, setter] = solidCreateOptimisticStore((draft) => {
    compute()(rootRef(draft));
  }, seed);
  return { store: () => store, setter };
};

export const updateOptimisticImpl = updateImpl;

export const affectsImpl = (cursor) => {
  solidAffects(cursor());
};
