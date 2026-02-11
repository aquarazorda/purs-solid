import { readFile } from "node:fs/promises";
import { cwd } from "node:process";
import { join } from "node:path";

const rootDir = cwd();

const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message);
  }
};

const ensureBuildArtifacts = async () => {
  const entry = join(rootDir, "output", "Solid.Start.Server.Runtime", "index.js");
  const serverMain = join(rootDir, "output", "Examples.StartSSRSmoke.ServerMain", "index.js");

  try {
    await readFile(entry);
  } catch {
    throw new Error(
      "Missing build output at output/Solid.Start.Server.Runtime/index.js. Run `spago build` first."
    );
  }

  try {
    await readFile(serverMain);
  } catch {
    throw new Error(
      "Missing build output at output/Examples.StartSSRSmoke.ServerMain/index.js. Run `spago build` first."
    );
  }
};

const tuple = (left, right) => ({ value0: left, value1: right });

const lookupHeader = (headers, key) => {
  const lowerKey = String(key).toLowerCase();
  const match = headers.find((entry) => String(entry.value0).toLowerCase() === lowerKey);
  return match == null ? null : String(match.value1);
};

const main = async () => {
  await ensureBuildArtifacts();

  const Runtime = await import("../../output/Solid.Start.Server.Runtime/index.js");
  const StartServerMain = await import("../../output/Examples.StartSSRSmoke.ServerMain/index.js");
  const Request = await import("../../output/Solid.Start.Server.Request/index.js");
  const Response = await import("../../output/Solid.Start.Server.Response/index.js");
  const DataEither = await import("../../output/Data.Either/index.js");
  const StartError = await import("../../output/Solid.Start.Error/index.js");

  const runtimeRequest = {
    method: "GET",
    path: "/api/smoke",
    headers: [tuple("accept", "application/json")],
    query: [tuple("debug", "1")],
    body: null,
  };

  const runtimeResponse = Runtime.handleRuntimeRequest((typedRequest) => () =>
    DataEither.Right.create(
      Response.text(200)(`ok:${Request.path(typedRequest)}`)
    )
  )(runtimeRequest)();

  assert(
    Runtime.runtimeResponseStatus(runtimeResponse) === 200,
    "Expected runtime response status 200"
  );
  assert(
    Runtime.runtimeResponseBody(runtimeResponse) === "ok:/api/smoke",
    "Expected runtime response body to include request path"
  );

  const errorResponse = Runtime.handleRuntimeRequest(() => () =>
    DataEither.Left.create(StartError.RouteNotFound.create("No route matched path: /missing"))
  )(runtimeRequest)();

  assert(
    Runtime.runtimeResponseStatus(errorResponse) === 404,
    "Expected RouteNotFound to map to 404 response"
  );

  const methodErrorResponse = Runtime.handleRuntimeRequest(() => () =>
    DataEither.Right.create(Response.text(200)("unused"))
  )({
    ...runtimeRequest,
    method: "TRACE",
  })();

  assert(
    Runtime.runtimeResponseStatus(methodErrorResponse) === 500,
    "Expected unsupported method to map to 500 response"
  );

  const integratedHealth = StartServerMain.handleRuntimeRequest({
    method: "GET",
    path: "/api/health",
    headers: [],
    query: [],
    body: null,
  })();

  assert(
    Runtime.runtimeResponseStatus(integratedHealth) === 200,
    "Expected integrated router /api/health to return 200"
  );
  assert(
    Runtime.runtimeResponseBody(integratedHealth) === "ok",
    "Expected integrated router /api/health to return ok body"
  );

  const integratedStream = StartServerMain.handleRuntimeRequest({
    method: "GET",
    path: "/api/stream",
    headers: [],
    query: [],
    body: null,
  })();

  assert(
    Runtime.runtimeResponseStatus(integratedStream) === 200,
    "Expected integrated router /api/stream to return 200"
  );
  assert(
    Runtime.runtimeResponseBodyKind(integratedStream) === "stream",
    "Expected integrated router /api/stream body kind to be stream"
  );
  assert(
    Runtime.runtimeResponseBody(integratedStream) === "chunk-1chunk-2chunk-3",
    "Expected integrated router /api/stream body text to concatenate chunks"
  );
  assert(
    JSON.stringify(Runtime.runtimeResponseStreamChunks(integratedStream)) === JSON.stringify(["chunk-1", "chunk-2", "chunk-3"]),
    "Expected integrated router /api/stream chunk metadata"
  );

  const integratedServerFunctionError = StartServerMain.handleRuntimeRequest({
    method: "POST",
    path: "/api/server-function",
    headers: [tuple("content-type", "text/plain")],
    query: [],
    body: "boom",
  })();

  assert(
    Runtime.runtimeResponseStatus(integratedServerFunctionError) === 400,
    "Expected integrated router /api/server-function invalid payload to return 400"
  );
  assert(
    Runtime.runtimeResponseBody(integratedServerFunctionError) === "unexpected payload",
    "Expected integrated router /api/server-function invalid payload body"
  );
  assert(
    lookupHeader(Runtime.runtimeResponseHeaders(integratedServerFunctionError), "x-start-error-kind") === "ServerFunctionExecutionError",
    "Expected integrated router /api/server-function to include x-start-error-kind header"
  );

  const integratedMissingRoute = StartServerMain.handleRuntimeRequest({
    method: "GET",
    path: "/api/missing",
    headers: [],
    query: [],
    body: null,
  })();

  assert(
    Runtime.runtimeResponseStatus(integratedMissingRoute) === 404,
    "Expected integrated router to map unknown API path to 404"
  );

  console.log("[start-server-smoke] passed");
};

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[start-server-smoke] ${message}`);
  process.exitCode = 1;
});
