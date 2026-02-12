import { readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

import { eventHandler } from "vinxi/http";

const repoRoot = resolve(process.cwd(), "../../..");

const serverMainPath = join(repoRoot, "output", "Examples.SolidStartSSR.Entry.ServerMain", "index.js");
const runtimePath = join(repoRoot, "output", "Solid.Start.Server.Runtime", "index.js");

const readRequestBody = async (request) => {
  const chunks = [];
  for await (const chunk of request) {
    chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk);
  }

  return Buffer.concat(chunks).toString("utf8");
};

const toTuple = (left, right) => ({ value0: String(left), value1: String(right) });

const toRuntimeRequest = async (request, url) => {
  const method = typeof request.method === "string" ? request.method : "GET";
  const body = method === "GET" || method === "HEAD" ? null : await readRequestBody(request);

  const headers = Object.entries(request.headers ?? {}).flatMap(([key, value]) => {
    if (Array.isArray(value)) {
      return value.map((entry) => toTuple(key, entry));
    }

    if (typeof value === "string") {
      return [toTuple(key, value)];
    }

    return [];
  });

  const query = Array.from(url.searchParams.entries()).map(([key, value]) => toTuple(key, value));

  return {
    method,
    path: decodeURIComponent(url.pathname),
    headers,
    query,
    body: body === "" ? null : body,
  };
};

const toWebHeaders = (pairs) => {
  const headers = new Headers();

  for (const pair of pairs) {
    const key = pair?.value0;
    const value = pair?.value1;
    if (typeof key !== "string" || key.length === 0 || typeof value !== "string") {
      continue;
    }

    headers.append(key, value);
  }

  return headers;
};

let outputReadyPromise;

const ensurePursOutput = () => {
  if (outputReadyPromise == null) {
    outputReadyPromise = Promise.all([readFile(serverMainPath), readFile(runtimePath)]).catch(() => {
      throw new Error(
        "Missing PureScript output for SolidStartSSR. Run `npm run build:purs` in src/Examples/SolidStartSSR first."
      );
    });
  }

  return outputReadyPromise;
};

let runtimePromise;

const loadRuntime = () => {
  if (runtimePromise == null) {
    runtimePromise = Promise.all([
      import(pathToFileURL(serverMainPath).href),
      import(pathToFileURL(runtimePath).href),
    ]).then(([serverMain, runtime]) => ({ serverMain, runtime }));
  }

  return runtimePromise;
};

export default eventHandler(async (event) => {
  await ensurePursOutput();
  const { serverMain, runtime } = await loadRuntime();

  const request = event.node.req;
  const url = new URL(request.url ?? "/", "http://localhost");

  const runtimeRequest = await toRuntimeRequest(request, url);
  const runtimeResponse = serverMain.handleRuntimeRequest(runtimeRequest)();

  const status = runtime.runtimeResponseStatus(runtimeResponse);
  const headers = toWebHeaders(runtime.runtimeResponseHeaders(runtimeResponse));
  const bodyKind = runtime.runtimeResponseBodyKind(runtimeResponse);

  if (bodyKind === "stream") {
    const chunks = runtime.runtimeResponseStreamChunks(runtimeResponse);
    return new Response(chunks.join(""), { status, headers });
  }

  return new Response(runtime.runtimeResponseBody(runtimeResponse), { status, headers });
});
