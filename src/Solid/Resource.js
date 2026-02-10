import { createResource as createSolidResource } from "solid-js/dist/solid.js";
import * as Data_Maybe from "../Data.Maybe/index.js";

const isJust = (maybe) => maybe instanceof Data_Maybe.Just;

const toMaybe = (value) =>
  value === undefined
    ? Data_Maybe.Nothing.value
    : Data_Maybe.Just.create(value);

const fromMaybe = (maybe) =>
  isJust(maybe)
    ? maybe.value0
    : undefined;

const toRefetchingMaybe = (refetching) => {
  if (refetching === undefined || refetching === false || refetching === true) {
    return Data_Maybe.Nothing.value;
  }

  return Data_Maybe.Just.create(refetching);
};

const toFetchInfo = (info) => ({
  value: toMaybe(info.value),
  refetching: toRefetchingMaybe(info.refetching),
  isRefetching: info.refetching !== undefined && info.refetching !== false,
});

const toParts = (pair) => ({ resource: pair[0], actions: pair[1] });

export const createResourceImpl = (fetcher) => () =>
  toParts(
    createSolidResource((_, info) => fetcher(toFetchInfo(info))())
  );

export const createResourceFromImpl = (sourceAccessor) => (fetcher) => () => {
  const source = () => {
    const maybeSource = sourceAccessor();

    return isJust(maybeSource)
      ? { value: maybeSource.value0 }
      : undefined;
  };

  return toParts(
    createSolidResource(source, (wrappedSource, info) =>
      fetcher(wrappedSource.value)(toFetchInfo(info))()
    )
  );
};

export const value = (resource) => () => {
  try {
    return toMaybe(resource());
  } catch (_) {
    return Data_Maybe.Nothing.value;
  }
};

export const latest = (resource) => () => {
  try {
    return toMaybe(resource.latest);
  } catch (_) {
    return Data_Maybe.Nothing.value;
  }
};

export const stateTagImpl = (resource) => () =>
  resource.state;

export const loading = (resource) => () =>
  resource.loading;

export const error = (resource) => () => {
  const currentError = resource.error;

  if (currentError === undefined) {
    return Data_Maybe.Nothing.value;
  }

  if (typeof currentError === "string") {
    return Data_Maybe.Just.create(currentError);
  }

  if (typeof currentError.message === "string") {
    return Data_Maybe.Just.create(currentError.message);
  }

  return Data_Maybe.Just.create(String(currentError));
};

export const mutate = (actions) => (nextValue) => () => {
  actions.mutate(fromMaybe(nextValue));
};

export const refetch = (actions) => (info) => () => {
  if (isJust(info)) {
    actions.refetch(info.value0);
    return;
  }

  actions.refetch();
};
