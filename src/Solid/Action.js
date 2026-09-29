import { action as solidAction, createOptimistic as solidCreateOptimistic } from "solid-js";

// Drives an `Action` as the generator Solid's `action` expects: `Write` steps
// run synchronously inside the transaction; `Await` steps yield a promise, and
// Solid re-enters the transaction and resumes with its result (or throws its
// error into the generator).
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

// Function values are boxed so Solid doesn't read them as compute/updater
// functions (same scheme as `Solid.Signal`).
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
