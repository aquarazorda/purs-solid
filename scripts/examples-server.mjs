import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { cwd } from "node:process";
import { extname, join, normalize } from "node:path";

const rootDir = cwd();

const mimeTypeByExtension = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
};

const ensureBuildArtifacts = async () => {
  const bundlePath = join(rootDir, "dist", "examples", "solid-start.js");

  try {
    await readFile(bundlePath);
  } catch {
    throw new Error("Missing build output at dist/examples/solid-start.js. Run `npm run build:example:solid-start` first.");
  }
};

const toAbsolutePath = (pathname) => {
  const requestedPath = pathname === "/" ? "/examples/solid-start/" : pathname;
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

const isSolidStartRoutePath = (pathname) => {
  if (typeof pathname !== "string") {
    return false;
  }

  return pathname === "/examples/solid-start" || pathname.startsWith("/examples/solid-start/");
};

export const createExamplesServer = async () => {
  await ensureBuildArtifacts();

  return createServer(async (request, response) => {
    if (!request.url) {
      response.writeHead(400, { "content-type": "text/plain; charset=utf-8" });
      response.end("Bad request");
      return;
    }

    const url = new URL(request.url, "http://127.0.0.1");
    const pathname = decodeURIComponent(url.pathname);

    if (pathname === "/api/server-function") {
      if (request.method !== "POST") {
        response.writeHead(405, { "content-type": "text/plain; charset=utf-8" });
        response.end("Method Not Allowed");
        return;
      }

      const body = await readRequestBody(request);
      if (body === "ping") {
        response.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
        response.end("pong");
        return;
      }

      response.writeHead(400, {
        "content-type": "text/plain; charset=utf-8",
        "x-start-error-kind": "ServerFunctionExecutionError",
      });
      response.end("unexpected payload");
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
      if (isSolidStartRoutePath(pathname) && extname(pathname) === "") {
        try {
          const fallbackPath = join(rootDir, "examples", "solid-start", "index.html");
          const fallbackFile = await readFile(fallbackPath);
          response.writeHead(200, { "content-type": mimeTypeByExtension[".html"] });
          response.end(fallbackFile);
          return;
        } catch {}
      }

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
