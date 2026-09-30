import { action, useAction, useSubmissions } from "@solidjs/router";

export const routerActionImpl = (name, run) => action((input) => run(input)(), name);

export const serverActionImpl = (name, fn) => action(fn, name);

export const formAction = (act) => act.url;

export const useActionImpl = (act) => () => {
  const run = useAction(act);
  return (input) => () => run(input).then((value) => value ?? null);
};

const toError = (error) => (error instanceof Error ? error : new Error(String(error)));

export const useSubmissionsImpl = (act) => () => {
  const submissions = useSubmissions(act);
  return () =>
    Array.from(submissions, (submission) => ({
      input: submission.input[0],
      result: submission.result ?? null,
      error: submission.error == null ? null : toError(submission.error),
      clear: () => submission.clear(),
      retry: () => submission.retry().then((value) => value ?? null),
    }));
};
