import {
  createMutable as createSolidMutable,
  createStore as createSolidStore,
  modifyMutable as modifySolidMutable,
  produce as solidProduce,
  reconcile as solidReconcile,
  unwrap as unwrapSolid,
} from "solid-js/store/dist/store.js";

const setValueAtPath = (target, path, value) => {
  if (path.length === 0) {
    return;
  }

  let current = target;

  for (let index = 0; index < path.length - 1; index += 1) {
    const key = path[index];
    const next = current[key];

    if (next == null || typeof next !== "object") {
      current[key] = {};
    }

    current = current[key];
  }

  current[path[path.length - 1]] = value;
};

const readValueAtPath = (target, path) => {
  if (path.length === 0) {
    return target;
  }

  let current = target;

  for (let index = 0; index < path.length; index += 1) {
    if (current == null) {
      return undefined;
    }

    current = current[path[index]];
  }

  return current;
};

export const createStoreImpl = (initial) => () => {
  const pair = createSolidStore(initial);

  return {
    store: pair[0],
    set: pair[1],
  };
};

export const get = (store) => () =>
  store;

export const unwrapStore = (store) => () =>
  unwrapSolid(store);

export const set = (setter) => (next) => () => {
  setter(next);
};

export const modify = (setter) => (update) => () => {
  setter((previous) => update(previous));
};

export const produce = (setter) => (recipe) => () => {
  setter(solidProduce((draft) => {
    recipe(draft)();
  }));
};

export const reconcile = (setter) => (next) => () => {
  setter(solidReconcile(next));
};

export const getFieldImpl = (field) => (store) => () =>
  store[field];

export const setFieldImpl = (field) => (setter) => (next) => () => {
  setter(field, next);
};

export const modifyFieldImpl = (field) => (setter) => (update) => () => {
  setter(field, (previous) => update(previous));
};

export const setPath = (setter) => (path) => (next) => () => {
  setter(...path, next);
};

export const modifyPath = (setter) => (path) => (update) => () => {
  setter(...path, (previous) => update(previous));
};

export const createMutable = (initial) => () =>
  createSolidMutable(initial);

export const getMutable = (mutable) => () =>
  mutable;

export const unwrapMutable = (mutable) => () =>
  unwrapSolid(mutable);

export const modifyMutable = (mutable) => (recipe) => () => {
  modifySolidMutable(mutable, (draft) => {
    recipe(draft)();
  });
};

export const getMutableFieldImpl = (field) => (mutable) => () =>
  mutable[field];

export const setMutableFieldImpl = (field) => (mutable) => (next) => () => {
  modifySolidMutable(mutable, (state) => {
    state[field] = next;
  });
};

export const modifyMutableFieldImpl = (field) => (mutable) => (update) => () => {
  modifySolidMutable(mutable, (state) => {
    state[field] = update(state[field]);
  });
};

export const setMutablePath = (mutable) => (path) => (next) => () => {
  modifySolidMutable(mutable, (state) => {
    setValueAtPath(state, path, next);
  });
};

export const modifyMutablePath = (mutable) => (path) => (update) => () => {
  modifySolidMutable(mutable, (state) => {
    const previous = readValueAtPath(state, path);
    setValueAtPath(state, path, update(previous));
  });
};
