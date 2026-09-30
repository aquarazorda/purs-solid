import { action as solidAction, createOptimistic as solidCreateOptimistic } from "solid-js";

export const actionImpl = (eliminate) => (toPromise) => (steps) => {
  const done = (value) => ({ tag: "done", value });
  const write = (effect) => ({ tag: "write", effect });
  const wait = (aff) => ({ tag: "await", aff });

  const run = solidAction(function* (input) {
    let step = steps(input);
    for (;;) {
      const next = eliminate(done)(write)(wait)(step);
      if (next.tag === "done") return next.value;
      if (next.tag === "write") step = next.effect();
      else step = yield toPromise(next.aff)();
    }
  });

  return (input) => run(input);
};

// Boxed so Solid doesn't treat function values as compute/updater functions.
const box = (value) => ({ value });

export const createOptimisticImpl = (initial) => {
  const [get, set] = solidCreateOptimistic(box(initial), { equals: (a, b) => a.value === b.value });
  return { get: () => get().value, set };
};

export const createOptimisticFromImpl = (source) => {
  const [get, set] = solidCreateOptimistic(() => box(source()), { equals: (a, b) => a.value === b.value });
  return { get: () => get().value, set };
};

export const setOptimisticImpl = (setter) => (value) => () => {
  setter(() => box(value));
};

export const modifyOptimisticImpl = (setter) => (f) => () => {
  setter((previous) => box(f(previous.value)));
};
