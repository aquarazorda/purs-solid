// Browser smoke tests: bundles the Counter and TodoMVC examples as production
// builds and drives them in headless Chromium.
//
//   npm run test:browser-smoke

import { execFileSync } from "node:child_process";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { delimiter, extname, join, normalize } from "node:path";
import { cwd, env } from "node:process";

const rootDir = cwd();
const mimeTypes = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8" };

const bundle = (module, outfile) => {
  execFileSync(
    "spago",
    ["bundle", "--module", module, "--bundle-type", "app", "--platform", "browser", "--minify", "--outfile", outfile],
    { stdio: "inherit", env: { ...env, PATH: `${join(rootDir, "node_modules", ".bin")}${delimiter}${env.PATH}` } }
  );
};

const serve = (appBundle) =>
  new Promise((resolve, reject) => {
    const server = createServer(async (request, response) => {
      const url = decodeURIComponent((request.url ?? "/").split("?")[0]);
      const path = url === "/dist/browser-smoke/app.js" ? appBundle : normalize(join(rootDir, url === "/" ? "/test/browser/page.html" : url));
      try {
        const file = await readFile(path);
        response.writeHead(200, { "content-type": mimeTypes[extname(path)] ?? "application/octet-stream" });
        response.end(file);
      } catch {
        response.writeHead(404).end();
      }
    });
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => resolve(server));
  });

let checks = 0;
const failures = [];
const expect = (label, actual, expected) => {
  checks += 1;
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    failures.push(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
};

const withPage = async (browser, appBundle, run) => {
  const server = await serve(appBundle);
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") errors.push(message.text());
  });
  try {
    await page.goto(`http://127.0.0.1:${server.address().port}/`);
    await run(page);
    expect("no page errors or warnings", errors, []);
  } finally {
    await page.close();
    server.close();
  }
};

const counter = async (page) => {
  const value = () => page.textContent(".counter-value");
  await page.waitForSelector(".counter-value");
  expect("counter starts at 0", await value(), "0");
  await page.click("text=+ step");
  await page.click("text=+ step");
  expect("+ step twice", await value(), "2");
  await page.click(".counter-presets >> text=5");
  await page.click("text=+ step");
  expect("step preset 5", await value(), "7");
  expect("doubled follows", await page.textContent(".counter-meta span"), "14");
  expect("trend class is reactive", await page.getAttribute(".counter-meta span:nth-of-type(2)", "class"), "positive");
  await page.click("text=Reset");
  expect("reset", await value(), "0");
  expect("event log entries", await page.locator(".counter-log li").count(), 6);
  await page.click(".counter-log-head >> text=Clear");
  expect("log cleared", await page.textContent(".counter-empty"), "No events yet.");
};

const todomvc = async (page) => {
  const add = async (title) => {
    await page.fill(".new-todo", title);
    await page.press(".new-todo", "Enter");
  };
  const titles = () => page.$$eval(".todo-list .todo .todo-title", (nodes) => nodes.map((n) => n.textContent));
  await page.waitForSelector(".new-todo");
  await add("write bindings");
  await add("ship solid 2");
  expect("todos added", await titles(), ["write bindings", "ship solid 2"]);
  expect("draft cleared (reactive value)", await page.inputValue(".new-todo"), "");
  expect("count", await page.textContent(".todo-count"), "2 items left");

  const firstRow = page.locator(".todo").first();
  const firstRowHandle = await firstRow.elementHandle();
  await firstRow.locator(".todo-toggle").check();
  expect("toggle marks completed", await firstRow.getAttribute("class"), "todo completed");
  expect("count after toggle", await page.textContent(".todo-count"), "1 item left");
  expect("row DOM reused after update", await page.evaluate((el) => el.isConnected, firstRowHandle), true);

  await page.click("text=Active");
  expect("active filter", await titles(), ["ship solid 2"]);
  expect("selected filter class", await page.getAttribute(".filters button:nth-child(2)", "class"), "filter-btn selected");
  await page.click("text=Completed");
  expect("completed filter", await titles(), ["write bindings"]);
  await page.click(".filters >> text=All");
  await page.click("text=Clear completed");
  expect("clear completed", await titles(), ["ship solid 2"]);
  await page.check(".toggle-all");
  expect("toggle all", await page.textContent(".todo-count"), "0 items left");
  await page.click(".destroy");
  expect("delete last todo shows empty state", await page.textContent(".empty-state"), "Add your first task to get started.");
};

const main = async () => {
  const counterBundle = join(rootDir, "dist", "browser-smoke", "counter.js");
  const todoBundle = join(rootDir, "dist", "browser-smoke", "todomvc.js");
  bundle("Examples.Counter", counterBundle);
  bundle("Examples.TodoMVC", todoBundle);

  const { chromium } = await import("playwright");
  const browser = await chromium.launch();
  try {
    await withPage(browser, counterBundle, counter);
    await withPage(browser, todoBundle, todomvc);
  } finally {
    await browser.close();
  }

  if (failures.length > 0) {
    console.error(`[browser-smoke] ${failures.length} of ${checks} checks failed:\n${failures.map((f) => `  - ${f}`).join("\n")}`);
    process.exitCode = 1;
  } else {
    console.log(`[browser-smoke] passed ${checks} checks`);
  }
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
