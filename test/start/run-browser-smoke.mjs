import { spawn } from "node:child_process";
import { once } from "node:events";
import { setTimeout as delay } from "node:timers/promises";

const asError = (error) => (error instanceof Error ? error : new Error(String(error)));

const loadPlaywright = async () => {
  try {
    return await import("playwright");
  } catch {
    throw new Error("Playwright is not installed. Run `npm install` first.");
  }
};

const npmCommand = process.platform === "win32" ? "npm.cmd" : "npm";

const startSolidStartDevServer = (port) => {
  const child = spawn(
    npmCommand,
    ["--prefix", "examples/solid-start", "run", "dev", "--", "--host", "127.0.0.1", "--port", String(port)],
    {
      cwd: process.cwd(),
      stdio: ["ignore", "pipe", "pipe"],
    }
  );

  child.stdout.on("data", (chunk) => {
    process.stdout.write(`[start-browser-smoke][dev] ${chunk}`);
  });

  child.stderr.on("data", (chunk) => {
    process.stderr.write(`[start-browser-smoke][dev] ${chunk}`);
  });

  return child;
};

const waitForServer = async (url, timeoutMs = 60000) => {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const response = await fetch(url);
      if (response.ok || response.status === 404) {
        return;
      }
    } catch {}

    await delay(500);
  }

  throw new Error(`Timed out waiting for dev server at ${url}`);
};

const stopServer = async (child) => {
  if (child == null || child.exitCode != null) {
    return;
  }

  child.kill("SIGTERM");

  const exited = Promise.race([
    once(child, "exit"),
    delay(5000).then(() => {
      child.kill("SIGKILL");
    }),
  ]);

  await exited;
};

const mockStories = [
  {
    id: 100,
    title: "PureScript Hacker News story",
    points: 42,
    user: "alice",
    time_ago: "1 hour",
    comments_count: 3,
    type: "link",
    url: "https://example.com/story",
    domain: "example.com",
  },
  {
    id: 101,
    title: "Second story",
    points: 10,
    user: "bob",
    time_ago: "2 hours",
    comments_count: 0,
    type: "ask",
    url: null,
    domain: null,
  },
];

const mockStoryDetail = {
  id: 100,
  title: "PureScript Hacker News story",
  points: 42,
  user: "alice",
  time_ago: "1 hour",
  comments_count: 1,
  type: "link",
  url: "https://example.com/story",
  domain: "example.com",
  comments: [
    {
      id: 500,
      user: "bob",
      time_ago: "30 minutes",
      content: "<p>Looks good.</p>",
      comments: [],
    },
  ],
};

const mockUser = {
  id: "alice",
  created: 1700000000,
  karma: 123,
  about: "<p>PureScript fan</p>",
};

const installApiMocks = async (page) => {
  await page.route("https://node-hnapi.herokuapp.com/**", async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname.startsWith("/item/")) {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(mockStoryDetail),
      });
      return;
    }

    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(mockStories),
    });
  });

  await page.route("https://hacker-news.firebaseio.com/v0/user/*.json", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(mockUser),
    });
  });
};

const main = async () => {
  const { chromium } = await loadPlaywright();
  const port = 3310;
  const baseUrl = `http://127.0.0.1:${port}`;
  const server = startSolidStartDevServer(port);
  let browser = null;

  try {
    await waitForServer(`${baseUrl}/`);

    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    await installApiMocks(page);

    await page.goto(`${baseUrl}/`, { waitUntil: "domcontentloaded" });
    await page.locator(".header .inner").first().waitFor({ timeout: 30000 });
    await page.waitForFunction(() => window.__PURS_SOLID_START_CLIENT_READY__ === true, null, {
      timeout: 30000,
    });

    const navHrefs = await page.locator(".header .inner > a").evaluateAll((nodes) =>
      nodes.slice(0, 5).map((node) => node.getAttribute("href"))
    );

    const expectedHrefs = ["/", "/new", "/show", "/ask", "/job"];
    if (JSON.stringify(navHrefs) !== JSON.stringify(expectedHrefs)) {
      throw new Error(`Unexpected nav hrefs: ${JSON.stringify(navHrefs)}`);
    }

    const navToken = await page.evaluate(() => {
      window.__START_NAV_TOKEN__ = Math.random().toString(36).slice(2);
      return window.__START_NAV_TOKEN__;
    });

    await page.locator('.header .inner > a:has-text("New")').click();
    await page.waitForURL(new RegExp(`${baseUrl.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/new/?$`));
    await page.locator(".news-item .title").first().waitFor({ timeout: 30000 });

    const tokenAfterNew = await page.evaluate(() => window.__START_NAV_TOKEN__);
    if (tokenAfterNew !== navToken) {
      throw new Error("Navigation to /new triggered a full page reload");
    }

    await page.locator(".news-item .meta a").nth(1).click();
    await page.waitForURL(new RegExp(`${baseUrl.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/stories/100/?$`));
    await page.locator(".item-view-header h1").first().waitFor({ timeout: 30000 });

    const tokenAfterStory = await page.evaluate(() => window.__START_NAV_TOKEN__);
    if (tokenAfterStory !== navToken) {
      throw new Error("Navigation to /stories/:id triggered a full page reload");
    }

    await page.locator(".item-view-header .meta a").first().click();
    await page.waitForURL(new RegExp(`${baseUrl.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/users/alice/?$`));
    await page.locator(".user-view h1").first().waitFor({ timeout: 30000 });

    const tokenAfterUser = await page.evaluate(() => window.__START_NAV_TOKEN__);
    if (tokenAfterUser !== navToken) {
      throw new Error("Navigation to /users/:id triggered a full page reload");
    }

    await page.locator('.header .inner > a:has-text("HN")').click();
    await page.waitForURL(new RegExp(`${baseUrl.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/?$`));

    const tokenAfterHome = await page.evaluate(() => window.__START_NAV_TOKEN__);
    if (tokenAfterHome !== navToken) {
      throw new Error("Navigation back to / triggered a full page reload");
    }

    console.log("[start-browser-smoke] passed");
  } finally {
    if (browser != null) {
      await browser.close();
    }

    await stopServer(server);
  }
};

main().catch((error) => {
  console.error(`[start-browser-smoke] ${asError(error).message}`);
  process.exitCode = 1;
});
