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

const ensureBuildArtifacts = async () => {
  const entry = join(rootDir, "dist", "examples", "solid-start.js");

  try {
    await readFile(entry);
  } catch {
    throw new Error(
      "Missing build output at dist/examples/solid-start.js. Run `npm run build:example:solid-start` first."
    );
  }
};

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
  await ensureBuildArtifacts();
  const { chromium } = await loadPlaywright();
  const server = createStaticServer();
  const port = await startServer(server);
  let browser = null;

  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    const url = `http://127.0.0.1:${port}/examples/solid-start/`;
    await page.goto(url, { waitUntil: "domcontentloaded" });
    await page.locator(".start-brand").first().waitFor({ timeout: 30000 });

    const navToken = await page.evaluate(() => {
      window.__START_NAV_TOKEN__ = Math.random().toString(36).slice(2);
      return window.__START_NAV_TOKEN__;
    });

    const title = await page.title();
    const heading = await page.locator(".start-brand").textContent();
    const counterHref = await page.locator('.start-nav a:has-text("Counter")').getAttribute("href");
    const todomvcHref = await page.locator('.start-nav a:has-text("TodoMVC")').getAttribute("href");

    if (title !== "purs-solid SolidStart Example") {
      throw new Error(`Unexpected page title: ${title}`);
    }

    if ((heading ?? "").trim() !== "purs-solid Start app") {
      throw new Error(`Unexpected page heading: ${heading}`);
    }

    if (counterHref !== "/examples/solid-start/counter/") {
      throw new Error(`Expected counter navigation link, got ${counterHref}`);
    }

    if (todomvcHref !== "/examples/solid-start/todomvc/") {
      throw new Error(`Expected todomvc navigation link, got ${todomvcHref}`);
    }

    await page.locator('.start-nav a:has-text("Counter")').click();
    await page.waitForURL(`http://127.0.0.1:${port}/examples/solid-start/counter/`);
    await page.locator(".counter-card h1").first().waitFor({ timeout: 30000 });
    const counterAppHeading = await page.locator(".counter-card h1").first().textContent();

    if ((counterAppHeading ?? "").trim() !== "Signal Counter") {
      throw new Error(`Counter route app did not load as expected: ${counterAppHeading}`);
    }

    const tokenAfterCounterClick = await page.evaluate(() => window.__START_NAV_TOKEN__);
    if (tokenAfterCounterClick !== navToken) {
      throw new Error("Counter navigation caused a full page reload");
    }

    await page.locator('.start-nav a:has-text("TodoMVC")').click();
    await page.waitForURL(`http://127.0.0.1:${port}/examples/solid-start/todomvc/`);
    await page.locator(".todoapp .header h1").first().waitFor({ timeout: 30000 });
    const todoAppHeading = await page.locator(".todoapp .header h1").first().textContent();

    if ((todoAppHeading ?? "").trim() !== "todos") {
      throw new Error(`TodoMVC route app did not load as expected: ${todoAppHeading}`);
    }

    const tokenAfterTodoClick = await page.evaluate(() => window.__START_NAV_TOKEN__);
    if (tokenAfterTodoClick !== navToken) {
      throw new Error("TodoMVC navigation caused a full page reload");
    }

    await page.goBack({ waitUntil: "domcontentloaded" });
    await page.waitForURL(`http://127.0.0.1:${port}/examples/solid-start/counter/`);
    await page.locator(".counter-card h1").first().waitFor({ timeout: 30000 });

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
