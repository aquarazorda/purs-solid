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

const asError = (error) => (error instanceof Error ? error : new Error(String(error)));

const toAbsolutePath = (urlPath) => {
  const withoutQuery = urlPath.split("?")[0];
  const decoded = decodeURIComponent(withoutQuery);
  const requestedPath = decoded === "/" ? "/examples/solid-start/" : decoded;
  const requested = requestedPath.endsWith("/") ? `${requestedPath}index.html` : requestedPath;
  const relative = requested.startsWith("/") ? requested.slice(1) : requested;
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

const loadPlaywright = async () => {
  try {
    return await import("playwright");
  } catch {
    throw new Error("Playwright is not installed. Run `npm install` first.");
  }
};

const main = async () => {
  const { chromium } = await loadPlaywright();
  const server = createStaticServer();
  const port = await startServer(server);
  let browser = null;

  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    const url = `http://127.0.0.1:${port}/examples/solid-start/`;
    await page.goto(url, { waitUntil: "domcontentloaded" });

    const title = await page.title();
    const heading = await page.locator("h1").textContent();
    const counterHref = await page.locator('.start-nav a[href="./counter/"]').getAttribute("href");
    const todomvcHref = await page.locator('.start-nav a[href="./todomvc/"]').getAttribute("href");

    if (title !== "purs-solid SolidStart Example") {
      throw new Error(`Unexpected page title: ${title}`);
    }

    if ((heading ?? "").trim() !== "purs-solid Start app") {
      throw new Error(`Unexpected page heading: ${heading}`);
    }

    if (counterHref !== "./counter/") {
      throw new Error(`Expected counter navigation link, got ${counterHref}`);
    }

    if (todomvcHref !== "./todomvc/") {
      throw new Error(`Expected todomvc navigation link, got ${todomvcHref}`);
    }

    await page.goto(`http://127.0.0.1:${port}/examples/solid-start/counter/`, { waitUntil: "domcontentloaded" });
    const counterRouteHeading = await page.locator(".start-card h2").textContent();
    if ((counterRouteHeading ?? "").trim() !== "/counter") {
      throw new Error(`Unexpected counter route heading: ${counterRouteHeading}`);
    }

    await page
      .frameLocator("iframe.start-frame")
      .locator("h1")
      .first()
      .waitFor({ timeout: 30000 });

    const counterAppHeading = await page
      .frameLocator("iframe.start-frame")
      .locator("h1")
      .first()
      .textContent();

    if ((counterAppHeading ?? "").trim() !== "Signal Counter") {
      throw new Error(`Counter iframe app did not load as expected: ${counterAppHeading}`);
    }

    await page.goto(`http://127.0.0.1:${port}/examples/solid-start/todomvc/`, { waitUntil: "domcontentloaded" });
    const todoRouteHeading = await page.locator(".start-card h2").textContent();
    if ((todoRouteHeading ?? "").trim() !== "/todomvc") {
      throw new Error(`Unexpected todomvc route heading: ${todoRouteHeading}`);
    }

    await page
      .frameLocator("iframe.start-frame")
      .locator("h1")
      .first()
      .waitFor({ timeout: 30000 });

    const todoAppHeading = await page
      .frameLocator("iframe.start-frame")
      .locator("h1")
      .first()
      .textContent();

    if ((todoAppHeading ?? "").trim() !== "todos") {
      throw new Error(`TodoMVC iframe app did not load as expected: ${todoAppHeading}`);
    }

    console.log("[start-browser-smoke] passed");
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
  console.error(`[start-browser-smoke] ${asError(error).message}`);
  process.exitCode = 1;
});
