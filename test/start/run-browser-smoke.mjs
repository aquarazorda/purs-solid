import { createExamplesServer, startExamplesServer } from "../../scripts/examples-server.mjs";

const asError = (error) => (error instanceof Error ? error : new Error(String(error)));

const loadPlaywright = async () => {
  try {
    return await import("playwright");
  } catch {
    throw new Error("Playwright is not installed. Run `npm install` first.");
  }
};

const main = async () => {
  const { chromium } = await loadPlaywright();
  const server = await createExamplesServer();
  const address = await startExamplesServer(server, 0, "127.0.0.1");
  const port = address.port;
  let browser = null;

  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    const url = `http://127.0.0.1:${port}/examples/solid-start/`;
    await page.goto(url, { waitUntil: "domcontentloaded" });
    await page.locator(".start-brand").first().waitFor({ timeout: 30000 });

    const bootstrapMode = await page.evaluate(() => window.__PURS_SOLID_START_BOOTSTRAP_MODE__);
    if (bootstrapMode === "failure") {
      throw new Error("Client entry bootstrap failed");
    }

    const navToken = await page.evaluate(() => {
      window.__START_NAV_TOKEN__ = Math.random().toString(36).slice(2);
      return window.__START_NAV_TOKEN__;
    });

    const heading = await page.locator(".start-brand").textContent();
    const counterHref = await page.locator('.start-nav a:has-text("Counter")').getAttribute("href");
    const todomvcHref = await page.locator('.start-nav a:has-text("TodoMVC")').getAttribute("href");
    const serverFnHref = await page.locator('.start-nav a:has-text("ServerFn")').getAttribute("href");

    if ((heading ?? "").trim() !== "purs-solid Start app") {
      throw new Error(`Unexpected page heading: ${heading}`);
    }

    if (counterHref !== "/examples/solid-start/counter/") {
      throw new Error(`Expected counter navigation link, got ${counterHref}`);
    }

    if (todomvcHref !== "/examples/solid-start/todomvc/") {
      throw new Error(`Expected todomvc navigation link, got ${todomvcHref}`);
    }

    if (serverFnHref !== "/examples/solid-start/server-function/") {
      throw new Error(`Expected server function navigation link, got ${serverFnHref}`);
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

    await page.locator('.start-nav a:has-text("ServerFn")').click();
    await page.waitForURL(`http://127.0.0.1:${port}/examples/solid-start/server-function/`);
    await page.locator('.start-card h2:has-text("Server function transport demo")').first().waitFor({ timeout: 30000 });

    const beforeCall = await page.locator('.start-card p:has-text("Last result:")').first().textContent();
    if ((beforeCall ?? "").trim() !== "Last result: idle") {
      throw new Error(`Unexpected initial server function result: ${beforeCall}`);
    }

    await page.locator("#server-fn-success").click();
    await page.waitForFunction(
      () => {
        const nodes = Array.from(document.querySelectorAll('.start-card p'));
        return nodes.some((node) => node.textContent?.trim() === "Last result: ok: pong");
      },
      undefined,
      { timeout: 30000 }
    );
    const afterCall = await page.locator('.start-card p:has-text("Last result:")').first().textContent();
    if ((afterCall ?? "").trim() !== "Last result: ok: pong") {
      throw new Error(`Unexpected server function result after call: ${afterCall}`);
    }

    await page.locator("#server-fn-error").click();
    await page.waitForFunction(
      () => {
        const nodes = Array.from(document.querySelectorAll('.start-card p'));
        return nodes.some((node) => node.textContent?.includes("ServerFunctionExecutionError"));
      },
      undefined,
      { timeout: 30000 }
    );
    const errorCall = await page.locator('.start-card p:has-text("Last result:")').first().textContent();
    if ((errorCall ?? "").trim() !== "Last result: error: ServerFunctionExecutionError \"unexpected payload\"") {
      throw new Error(`Unexpected server function result after error call: ${errorCall}`);
    }

    const tokenAfterServerFnClick = await page.evaluate(() => window.__START_NAV_TOKEN__);
    if (tokenAfterServerFnClick !== navToken) {
      throw new Error("ServerFn navigation caused a full page reload");
    }

    await page.goBack({ waitUntil: "domcontentloaded" });
    await page.waitForURL(`http://127.0.0.1:${port}/examples/solid-start/todomvc/`);
    await page.locator(".todoapp .header h1").first().waitFor({ timeout: 30000 });

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
