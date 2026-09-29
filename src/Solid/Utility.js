import {
  batch as solidBatch,
  catchError as solidCatchError,
  from as solidFrom,
  getOwner as solidGetOwner,
  indexArray as solidIndexArray,
  mapArray as solidMapArray,
  mergeProps as solidMergeProps,
  observable as solidObservable,
  runWithOwner as solidRunWithOwner,
  splitProps as solidSplitProps,
  startTransition as solidStartTransition,
  useTransition as solidUseTransition,
  untrack as solidUntrack,
} from "solid-js";

// Functions taking `just`/`nothing` receive `Data.Maybe.Just`/`Nothing` from PureScript,
// so results that are legitimately `undefined` (e.g. `unit`) stay distinguishable.

export const batch = (action) => () =>
  solidBatch(() => action());

const toErrorMessage = (error) => {
  if (typeof error === "string") {
    return error;
  }

  if (error instanceof Error && typeof error.message === "string") {
    return error.message;
  }

  return String(error);
};

export const catchErrorImpl = (just) => (nothing) => (attempt) => (recover) => () =>
  {
    let failed = false;

    const result = solidCatchError(
      () => {
        try {
          return attempt();
        } catch (error) {
          failed = true;
          recover(toErrorMessage(error))();
          return undefined;
        }
      },
      (error) => {
        failed = true;
        recover(toErrorMessage(error))();
      }
    );

    if (failed) {
      return nothing;
    }

    return just(result);
  };

export const fromImpl = (just) => (nothing) => (subscribe) => () => {
  const stream = solidFrom((set) => {
    const cleanup = subscribe((value) => () => set(value))();

    return () => {
      cleanup();
    };
  });

  return () => {
    const current = stream();
    return current === undefined
      ? nothing
      : just(current);
  };
};

export const fromWithInitial = (initial) => (subscribe) => () =>
  solidFrom((set) => {
    const cleanup = subscribe((value) => () => set(value))();

    return () => {
      cleanup();
    };
  }, initial);

export const indexArray = (list) => (mapItem) => () =>
  solidIndexArray(list, (itemAccessor, index) => mapItem(itemAccessor)(index)());

export const mapArray = (list) => (mapItem) => () =>
  solidMapArray(list, (item, indexAccessor) => mapItem(item)(indexAccessor)());

export const mergeProps2 = (left) => (right) =>
  solidMergeProps(left, right);

export const mergeProps3 = (first) => (second) => (third) =>
  solidMergeProps(first, second, third);

export const mergePropsMany = (values) =>
  solidMergeProps(...values);

export const observable = (accessor) => () =>
  solidObservable(accessor);

export const splitProps = (props) => (keys) => {
  const [picked, omitted] = solidSplitProps(props, keys);
  return { picked, omitted };
};

export const startTransition = (action) => () => {
  void solidStartTransition(() => {
    action();
  });
};

export const useTransitionImpl = () => {
  const [pending, start] = solidUseTransition();

  return {
    pending,
    start: (action) => () => {
      void start(() => {
        action();
      });
    },
  };
};

export const untrack = (action) => () =>
  solidUntrack(() => action());

export const getOwnerImpl = () =>
  solidGetOwner();

export const runWithOwner = (owner) => (action) => () =>
  solidRunWithOwner(owner, () => action());

export const onImpl = (just) => (nothing) => (accessor) => (defer) => (run) => {
  let initialized = false;
  let previous;

  return () => {
    const current = accessor();

    if (!initialized) {
      initialized = true;
      previous = current;

      if (defer) {
        return undefined;
      }

      return run(current)(nothing)();
    }

    const result = run(current)(just(previous))();
    previous = current;

    return result;
  };
};
