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

  try {
    await readFile(entry);
  } catch {
    throw new Error(
      "Missing build output at output/Solid.Start.Server.Runtime/index.js. Run `spago build` first."
    );
  }
};

const tuple = (left, right) => ({ value0: left, value1: right });

const main = async () => {
  await ensureBuildArtifacts();

  const Runtime = await import("../../output/Solid.Start.Server.Runtime/index.js");
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

  console.log("[start-server-smoke] passed");
};

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[start-server-smoke] ${message}`);
  process.exitCode = 1;
});
