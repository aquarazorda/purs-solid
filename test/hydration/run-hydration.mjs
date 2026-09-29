// Hydration end-to-end: renders Examples.Hydration.App on the server (Node's
// default conditions select Solid's server build), serves the page with a
// production client bundle, and checks in Chromium that hydration claims the
// server DOM instead of recreating it.
//
//   npm run test:hydration

import { execFileSync } from "node:child_process";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { delimiter, join } from "node:path";
import { pathToFileURL } from "node:url";
import { cwd, env } from "node:process";

const rootDir = cwd();
const clientBundle = join(rootDir, "dist", "hydration", "client.js");

execFileSync(
  "spago",
  ["bundle", "--module", "Examples.Hydration.Client", "--bundle-type", "app", "--platform", "browser", "--minify", "--outfile", clientBundle],
  { stdio: "inherit", env: { ...env, PATH: `${join(rootDir, "node_modules", ".bin")}${delimiter}${env.PATH}` } }
);

const { renderPage } = await import(pathToFileURL(join(rootDir, "output", "Examples.Hydration.Server", "index.js")).href);
const page = await renderPage();
const serverFetches = globalThis.__pursSolidFetches ?? 0;

let checks = 0;
const failures = [];
const expect = (label, actual, expected) => {
  checks += 1;
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    failures.push(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
};

expect("server fetched the async value once", serverFetches, 1);
expect("server HTML has the resolved async value", page.includes("greeting from the server"), true);

const server = createServer(async (request, response) => {
  if (request.url === "/client.js") {
    response.writeHead(200, { "content-type": "text/javascript; charset=utf-8" });
    response.end(await readFile(clientBundle));
    return;
  }
  response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  response.end(page);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));

const { chromium } = await import("playwright");
const browser = await chromium.launch();
try {
  const tab = await browser.newPage();
  const problems = [];
  tab.on("pageerror", (error) => problems.push(error.message));
  tab.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") problems.push(message.text());
  });

  await tab.goto(`http://127.0.0.1:${server.address().port}/`);
  await tab.waitForFunction(() => window.__pursSolidHydrated === true, null, { timeout: 5000 });

  const reused = await tab.evaluate(() => {
    const all = Array.from(document.querySelectorAll("#app *"));
    return { total: all.length, fromServer: all.filter((el) => el.__ssr === true).length };
  });
  expect("every element was claimed, none recreated", reused.fromServer, reused.total);
  expect("client did not refetch the serialized async value", await tab.evaluate(() => window.__pursSolidFetches ?? 0), 0);
  expect("async value shows after hydration", await tab.textContent("#greeting"), "greeting from the server");

  const button = await tab.$("#increment");
  await tab.click("#increment");
  expect("hydrated handler updates text", await tab.textContent("#increment"), "clicked 1 times");
  expect("hydrated reactive attribute", await tab.getAttribute("#increment", "title"), "count 1");
  expect("hydrated reactive class", await tab.getAttribute("#increment", "class"), "odd");
  expect("button element kept", await tab.evaluate((el) => el.__ssr === true && el.isConnected, button), true);

  await tab.click("#add");
  expect("list keeps hydrated rows and appends", await tab.$$eval("#items li", (lis) => lis.map((li) => [li.textContent, li.__ssr === true])), [["alpha", true], ["beta", true], ["gamma", false]]);

  await tab.click("#toggle");
  expect("hydrated conditional switches branch", await tab.textContent("#detail"), "shown");
  await tab.click("#toggle");
  expect("and back", await tab.textContent("#no-detail"), "hidden");

  expect("svg kept its namespace", await tab.evaluate(() => document.querySelector("#app circle").namespaceURI), "http://www.w3.org/2000/svg");
  expect("no page errors, hydration mismatches or warnings", problems, []);
} finally {
  await browser.close();
  server.close();
}

if (failures.length > 0) {
  console.error(`[hydration] ${failures.length} of ${checks} checks failed:\n${failures.map((f) => `  - ${f}`).join("\n")}`);
  process.exitCode = 1;
} else {
  console.log(`[hydration] passed ${checks} checks`);
}
