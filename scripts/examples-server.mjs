import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { cwd } from "node:process";
import { extname, join, normalize } from "node:path";
import { pathToFileURL } from "node:url";

const rootDir = cwd();

const mimeTypeByExtension = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
};

const ensureBuildArtifacts = async () => {
  const ssrBundlePath = join(rootDir, "dist", "examples", "solid-start-ssr-client.js");
  const ssrServerModulePath = join(rootDir, "output", "Examples.SolidStartSSR.Entry.ServerMain", "index.js");
  const runtimeModulePath = join(rootDir, "output", "Solid.Start.Server.Runtime", "index.js");

  try {
    await readFile(ssrBundlePath);
  } catch {
    throw new Error("Missing build output at dist/examples/solid-start-ssr-client.js. Run `npm run build:example:solid-start-ssr` first.");
  }

  try {
    await readFile(ssrServerModulePath);
  } catch {
    throw new Error("Missing build output at output/Examples.SolidStartSSR.Entry.ServerMain/index.js. Run `npm run build:example:solid-start-ssr` first.");
  }

  try {
    await readFile(runtimeModulePath);
  } catch {
    throw new Error("Missing build output at output/Solid.Start.Server.Runtime/index.js. Run `npm run build:example:solid-start-ssr` first.");
  }
};

const toAbsolutePath = (pathname) => {
  const requestedPath = pathname === "/" ? "/examples/" : pathname;
  const requested = requestedPath.endsWith("/") ? `${requestedPath}index.html` : requestedPath;
  const relative = requested.startsWith("/") ? requested.slice(1) : requested;
  const absolutePath = normalize(join(rootDir, relative));
  const normalizedRoot = normalize(rootDir);

  if (absolutePath !== normalizedRoot && !absolutePath.startsWith(normalizedRoot + "/")) {
    return null;
  }

  return absolutePath;
};

const readRequestBody = async (request) => {
  const chunks = [];

  for await (const chunk of request) {
    chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk);
  }

  return Buffer.concat(chunks).toString("utf8");
};

const isSolidStartSsrPath = (pathname) => {
  if (typeof pathname !== "string") {
    return false;
  }

  return pathname === "/examples/solid-start-ssr" || pathname.startsWith("/examples/solid-start-ssr/");
};

const tuple = (left, right) => ({ value0: left, value1: right });

const normalizeRuntimeHeaders = (headers) => {
  if (headers == null || typeof headers !== "object") {
    return [];
  }

  const pairs = [];
  for (const [key, value] of Object.entries(headers)) {
    if (Array.isArray(value)) {
      for (const item of value) {
        pairs.push(tuple(String(key), String(item)));
      }
    } else if (value != null) {
      pairs.push(tuple(String(key), String(value)));
    }
  }

  return pairs;
};

const normalizeRuntimeQuery = (url) =>
  Array.from(url.searchParams.entries()).map(([key, value]) => tuple(String(key), String(value)));

const toRuntimeRequest = async (request, url) => {
  const method = typeof request.method === "string" ? request.method : "GET";
  const body = method === "GET" || method === "HEAD" ? null : await readRequestBody(request);

  return {
    method,
    path: decodeURIComponent(url.pathname),
    headers: normalizeRuntimeHeaders(request.headers),
    query: normalizeRuntimeQuery(url),
    body: body === "" ? null : body,
  };
};

const toNodeHeaders = (runtimeHeaders) => {
  const headers = {};
  for (const entry of runtimeHeaders) {
    if (entry == null || typeof entry !== "object") {
      continue;
    }

    const key = String(entry.value0 ?? "");
    if (key.length === 0) {
      continue;
    }

    headers[key] = String(entry.value1 ?? "");
  }

  return headers;
};

const loadSolidStartSsrRuntime = async () => {
  const serverMainPath = join(rootDir, "output", "Examples.SolidStartSSR.Entry.ServerMain", "index.js");
  const runtimePath = join(rootDir, "output", "Solid.Start.Server.Runtime", "index.js");

  const [serverMain, runtime] = await Promise.all([
    import(pathToFileURL(serverMainPath).href),
    import(pathToFileURL(runtimePath).href),
  ]);

  return { serverMain, runtime };
};

export const createExamplesServer = async () => {
  await ensureBuildArtifacts();
  const solidStartSsr = await loadSolidStartSsrRuntime();

  return createServer(async (request, response) => {
    if (!request.url) {
      response.writeHead(400, { "content-type": "text/plain; charset=utf-8" });
      response.end("Bad request");
      return;
    }

    const url = new URL(request.url, "http://127.0.0.1");
    const pathname = decodeURIComponent(url.pathname);

    if (isSolidStartSsrPath(pathname)) {
      const runtimeRequest = await toRuntimeRequest(request, url);
      const runtimeResponse = solidStartSsr.serverMain.handleRuntimeRequest(runtimeRequest)();
      const status = solidStartSsr.runtime.runtimeResponseStatus(runtimeResponse);
      const headers = toNodeHeaders(solidStartSsr.runtime.runtimeResponseHeaders(runtimeResponse));
      const body = solidStartSsr.runtime.runtimeResponseBody(runtimeResponse);
      response.writeHead(status, headers);
      response.end(body);
      return;
    }

    const absolutePath = toAbsolutePath(pathname);
    if (absolutePath == null) {
      response.writeHead(403, { "content-type": "text/plain; charset=utf-8" });
      response.end("Forbidden");
      return;
    }

    try {
      const file = await readFile(absolutePath);
      const extension = extname(absolutePath);
      const contentType = mimeTypeByExtension[extension] ?? "application/octet-stream";
      response.writeHead(200, { "content-type": contentType });
      response.end(file);
    } catch {
      response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
      response.end("Not found");
    }
  });
};

export const startExamplesServer = async (server, port = 0, host = "127.0.0.1") =>
  new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, () => {
      server.removeListener("error", reject);
      const address = server.address();

      if (address == null || typeof address === "string") {
        reject(new Error("Could not determine server address"));
        return;
      }

      resolve(address);
    });
  });
