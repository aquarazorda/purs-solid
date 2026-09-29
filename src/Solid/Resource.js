import { createResource as createSolidResource } from "solid-js";

// Fetchers arrive from PureScript already unwrapped: they return the value or throw.
// `Maybe` values are built with the `just`/`nothing` arguments passed from PureScript.

const toRefetchingValue = (refetching) =>
  refetching === undefined || refetching === false || refetching === true
    ? undefined
    : refetching;

const toFetchInfo = (just, nothing, info) => {
  const refetching = toRefetchingValue(info.refetching);

  return {
    value: info.value === undefined ? nothing : just(info.value),
    refetching: refetching === undefined ? nothing : just(refetching),
    isRefetching: info.refetching !== undefined && info.refetching !== false,
  };
};

const toParts = (pair) => ({ resource: pair[0], actions: pair[1] });

export const createResourceImpl = (just) => (nothing) => (fetcher) => () =>
  toParts(
    createSolidResource((_, info) =>
      fetcher(toFetchInfo(just, nothing, info))()
    )
  );

// `source` yields `{ value }` or `undefined`; the wrapper keeps falsy source values fetchable.
export const createResourceFromImpl = (just) => (nothing) => (source) => (fetcher) => () =>
  toParts(
    createSolidResource(source, (wrappedSource, info) =>
      fetcher(wrappedSource.value)(toFetchInfo(just, nothing, info))()
    )
  );

export const readValueImpl = (resource) => () =>
  resource();

export const readLatestImpl = (resource) => () =>
  resource.latest;

export const stateTagImpl = (resource) => () =>
  resource.state;

export const loading = (resource) => () =>
  resource.loading;

export const errorImpl = (resource) => () => {
  const currentError = resource.error;

  if (currentError === undefined) {
    return null;
  }

  if (typeof currentError === "string") {
    return currentError;
  }

  if (typeof currentError.message === "string") {
    return currentError.message;
  }

  return String(currentError);
};

export const mutateImpl = (actions) => (nextValue) => () => {
  actions.mutate(nextValue ?? undefined);
};

export const refetchImpl = (actions) => () => {
  actions.refetch();
};

export const refetchWithImpl = (actions) => (info) => () => {
  actions.refetch(info);
};

export const sourceBoxImpl = (toBox) => (source) => () =>
  toBox(source()) ?? undefined;
