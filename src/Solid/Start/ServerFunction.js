import { invoke, SERVER_FUNCTION_INVOKE } from "@solidjs/web/server-functions";

const serverFunctionTag = Symbol.for("purs-solid/server-function");

export const serverFunctionImpl = (run) => Object.assign((argument) => run(argument)(), { [serverFunctionTag]: true });

const toError = (error) => (error instanceof Error ? error : new Error(String(error)));

// Transformed references take per-call options through `invoke`; on the
// server without the plugin a server function is just the function.
export const callImpl = (options, fn, argument, onValue, onError) => {
  const controller = new AbortController();
  const callOptions = { ...options, signal: controller.signal };
  const call = () =>
    typeof fn[SERVER_FUNCTION_INVOKE] === "function" ? invoke(fn, callOptions, argument) : fn(argument);
  Promise.resolve()
    .then(call)
    .then(onValue, (error) => {
      if (!controller.signal.aborted) onError(toError(error));
    });
  return () => controller.abort();
};
