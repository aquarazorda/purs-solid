import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { cwd } from "node:process";
import { extname, join, normalize } from "node:path";
import { pathToFileURL } from "node:url";

const rootDir = cwd();

const mimeTypeByExtension = {
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
};

const asError = (error) => (error instanceof Error ? error : new Error(String(error)));

const ensureBuildArtifacts = async () => {
  const clientBundle = join(rootDir, "dist", "examples", "start-ssr-smoke-client.js");
  const serverOutput = join(rootDir, "output", "Examples.StartSSRSmoke.ServerMain", "index.js");

  try {
    await readFile(clientBundle);
  } catch {
    throw new Error(
      "Missing build output at dist/examples/start-ssr-smoke-client.js. Run `npm run build:example:start-ssr-smoke` first."
    );
  }

  try {
    await readFile(serverOutput);
  } catch {
    throw new Error(
      "Missing build output at output/Examples.StartSSRSmoke.ServerMain/index.js. Run `spago build` first."
    );
  }
};

const toAbsolutePath = (pathname) => {
  const relative = pathname.startsWith("/") ? pathname.slice(1) : pathname;
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

const toTuple = (left, right) => ({ value0: String(left), value1: String(right) });

const toRuntimeRequest = async (request, pathname, searchParams) => {
  const headers = Object.entries(request.headers ?? {}).flatMap(([key, value]) => {
    if (Array.isArray(value)) {
      return value.map((entry) => toTuple(key, entry));
    }

    if (typeof value === "string") {
      return [toTuple(key, value)];
    }

    return [];
  });

  const query = Array.from(searchParams.entries()).map(([key, value]) => toTuple(key, value));
  const body = request.method === "GET" || request.method === "HEAD"
    ? null
    : await readRequestBody(request);

  return {
    method: request.method ?? "GET",
    path: pathname,
    headers,
    query,
    body,
  };
};

const decorateDocument = (html) => {
  const headInsert =
    "<title>purs-solid Start SSR smoke</title>" +
    "<script>window.__PURS_SOLID_SSR_SMOKE_MODE__='ssr';</script>";

  const bodyInsert =
    "<script type=\"module\" src=\"/dist/examples/start-ssr-smoke-client.js\"></script>";

  let next = html;

  if (next.includes("</head>")) {
    next = next.replace("</head>", `${headInsert}</head>`);
  }

  if (next.includes("</body>")) {
    next = next.replace("</body>", `${bodyInsert}</body>`);
  }

  return next;
};

const loadServerHandler = async () => {
  const serverPath = pathToFileURL(join(rootDir, "output", "Examples.StartSSRSmoke.ServerMain", "index.js")).href;
  const runtimePath = pathToFileURL(join(rootDir, "output", "Solid.Start.Server.Runtime", "index.js")).href;

  const [ServerMain, Runtime] = await Promise.all([
    import(serverPath),
    import(runtimePath),
  ]);

  return {
    handleRuntimeRequest: ServerMain.handleRuntimeRequest,
    runtimeResponseStatus: Runtime.runtimeResponseStatus,
    runtimeResponseHeaders: Runtime.runtimeResponseHeaders,
    runtimeResponseBody: Runtime.runtimeResponseBody,
    runtimeResponseBodyKind: Runtime.runtimeResponseBodyKind,
    runtimeResponseStreamChunks: Runtime.runtimeResponseStreamChunks,
  };
};

const createSsrServer = async () => {
  const runtime = await loadServerHandler();

  return createServer(async (request, response) => {
    if (!request.url) {
      response.writeHead(400, { "content-type": "text/plain; charset=utf-8" });
      response.end("Bad request");
      return;
    }

    const url = new URL(request.url, "http://127.0.0.1");
    const pathname = decodeURIComponent(url.pathname);

    if (pathname === "/ssr") {
      response.writeHead(302, { location: "/ssr/" });
      response.end();
      return;
    }

    if (pathname.startsWith("/dist/") || pathname.startsWith("/output/") || pathname.startsWith("/node_modules/")) {
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
      return;
    }

    const runtimeRequest = await toRuntimeRequest(request, pathname, url.searchParams);
    const runtimeResponse = runtime.handleRuntimeRequest(runtimeRequest)();

    const status = runtime.runtimeResponseStatus(runtimeResponse);
    const headers = runtime.runtimeResponseHeaders(runtimeResponse);
    const headerEntries = headers.map((entry) => [entry.value0, entry.value1]);
    const bodyKind = runtime.runtimeResponseBodyKind(runtimeResponse);

    let bodyText = runtime.runtimeResponseBody(runtimeResponse);
    if (pathname === "/ssr/" && bodyKind === "html") {
      bodyText = decorateDocument(bodyText);
    }

    if (bodyKind === "stream") {
      response.writeHead(status, Object.fromEntries(headerEntries));
      const chunks = runtime.runtimeResponseStreamChunks(runtimeResponse);
      for (const chunk of chunks) {
        response.write(chunk);
      }
      response.end();
      return;
    }

    response.writeHead(status, Object.fromEntries(headerEntries));
    response.end(bodyText);
  });
};

const startServer = async (server) =>
  new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      server.removeListener("error", reject);
      const address = server.address();

      if (address == null || typeof address === "string") {
        reject(new Error("Could not determine server address"));
        return;
      }

      resolve(address.port);
    });
  });

const loadPlaywright = async () => {
  try {
    return await import("playwright");
  } catch {
    throw new Error("Playwright is not installed. Run `npm install` first.");
  }
};

const main = async () => {
  await ensureBuildArtifacts();
  const { chromium } = await loadPlaywright();
  const server = await createSsrServer();
  const port = await startServer(server);
  let browser = null;

  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    await page.goto(`http://127.0.0.1:${port}/ssr/`, { waitUntil: "domcontentloaded" });

    await page.waitForFunction(
      () => window.__PURS_SOLID_SSR_SMOKE_MODE__ !== "ssr",
      undefined,
      { timeout: 30000 }
    );

    const mode = await page.evaluate(() => window.__PURS_SOLID_SSR_SMOKE_MODE__);
    if (mode !== "hydrate") {
      throw new Error(`Expected hydration mode, got ${mode}`);
    }

    const appText = await page.locator("#app").textContent();
    if ((appText ?? "").trim() !== "ssr-hydration-smoke") {
      throw new Error(`Unexpected hydrated app text: ${appText}`);
    }

    const apiHealth = await page.evaluate(async () => {
      const response = await fetch("/api/health");
      return { status: response.status, text: await response.text() };
    });

    if (apiHealth.status !== 200 || apiHealth.text !== "ok") {
      throw new Error(`Unexpected /api/health response: ${JSON.stringify(apiHealth)}`);
    }

    const apiStream = await page.evaluate(async () => {
      const response = await fetch("/api/stream");
      return { status: response.status, text: await response.text() };
    });

    if (apiStream.status !== 200 || apiStream.text !== "chunk-1chunk-2chunk-3") {
      throw new Error(`Unexpected /api/stream response: ${JSON.stringify(apiStream)}`);
    }

    console.log("[start-ssr-hydration-smoke] passed");
  } finally {
    if (browser != null) {
      await browser.close();
    }

    await new Promise((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }

        resolve();
      });
    });
  }
};

main().catch((error) => {
  console.error(`[start-ssr-hydration-smoke] ${asError(error).message}`);
  process.exitCode = 1;
});
