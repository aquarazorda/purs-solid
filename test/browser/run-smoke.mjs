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
  ".map": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
};

const asError = (error) => {
  if (error instanceof Error) {
    return error;
  }

  return new Error(String(error));
};

const toAbsolutePath = (urlPath) => {
  const withoutQuery = urlPath.split("?")[0];
  const decoded = decodeURIComponent(withoutQuery);
  const requested = decoded === "/"
    ? "/test/browser/smoke.html"
    : decoded;

  const relative = requested.startsWith("/")
    ? requested.slice(1)
    : requested;

  const absolutePath = normalize(join(rootDir, relative));
  const normalizedRoot = normalize(rootDir);

  if (absolutePath !== normalizedRoot && !absolutePath.startsWith(normalizedRoot + "/")) {
    return null;
  }

  return absolutePath;
};

const createStaticServer = () =>
  createServer(async (request, response) => {
    if (!request.url) {
      response.writeHead(400, { "content-type": "text/plain; charset=utf-8" });
      response.end("Bad request");
      return;
    }

    const absolutePath = toAbsolutePath(request.url);

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

const ensureBuildArtifacts = async () => {
  const entry = join(rootDir, "output", "Solid.Web", "index.js");

  try {
    await readFile(entry);
  } catch {
    throw new Error(
      "Missing build output at output/Solid.Web/index.js. Run `spago test` first."
    );
  }
};

const loadPlaywright = async () => {
  try {
    return await import("playwright");
  } catch {
    throw new Error(
      "Playwright is not installed. Run `npm install` first."
    );
  }
};

const renderFailureReport = (result) => {
  if (result == null || typeof result !== "object") {
    return "Browser smoke result missing or malformed";
  }

  const failures = Array.isArray(result.failures)
    ? result.failures
    : [];

  const lines = failures.map((failure, index) =>
    `${index + 1}. ${failure.label}: ${failure.details}`
  );

  return [
    `Browser smoke failed (${failures.length} checks):`,
    ...lines,
  ].join("\n");
};

const main = async () => {
  await ensureBuildArtifacts();
  const { chromium } = await loadPlaywright();

  const server = createStaticServer();
  const port = await startServer(server);
  let browser = null;
  let page = null;
  const pageErrors = [];
  const requestErrors = [];

  try {
    browser = await chromium.launch({ headless: true });
    page = await browser.newPage();

    page.on("pageerror", (error) => {
      pageErrors.push(asError(error).message);
    });

    page.on("console", (message) => {
      if (message.type() === "error") {
        pageErrors.push(message.text());
      }
    });

    page.on("requestfailed", (request) => {
      requestErrors.push(`${request.url()} :: ${request.failure()?.errorText ?? "unknown"}`);
    });

    const url = `http://127.0.0.1:${port}/test/browser/smoke.html`;
    await page.goto(url, { waitUntil: "domcontentloaded" });

    try {
      await page.waitForFunction(
        () => window.__PURS_SOLID_SMOKE_RESULT__ !== undefined,
        undefined,
        { timeout: 15000 }
      );
    } catch (error) {
      const html = await page.content();
      const details = [
        asError(error).message,
        pageErrors.length > 0 ? `page errors:\n${pageErrors.join("\n")}` : null,
        requestErrors.length > 0 ? `request failures:\n${requestErrors.join("\n")}` : null,
        `page snippet:\n${html.slice(0, 1000)}`,
      ].filter(Boolean);

      throw new Error(details.join("\n\n"));
    }

    const result = await page.evaluate(() => window.__PURS_SOLID_SMOKE_RESULT__);

    if (pageErrors.length > 0 || requestErrors.length > 0) {
      const details = [];

      if (pageErrors.length > 0) {
        details.push(`page errors:\n${pageErrors.join("\n")}`);
      }

      if (requestErrors.length > 0) {
        details.push(`request failures:\n${requestErrors.join("\n")}`);
      }

      throw new Error(details.join("\n\n"));
    }

    if (!result?.ok) {
      throw new Error(renderFailureReport(result));
    }

    console.log(`[browser-smoke] passed ${result.checks} checks`);
  } finally {
    if (page != null) {
      await page.close();
    }

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
  console.error(`[browser-smoke] ${asError(error).message}`);
  process.exitCode = 1;
});
