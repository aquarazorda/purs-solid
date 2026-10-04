import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { bundle, checks, launch, rootDir, serve, watchProblems } from "../support.mjs";

const { expect, report } = checks("hydration");
const clientBundle = join(rootDir, "dist", "hydration", "client.js");
bundle("Examples.Hydration.Client", clientBundle);

const { renderPage } = await import(pathToFileURL(join(rootDir, "output", "Examples.Hydration.Server", "index.js")).href);
const { html, fetches } = await renderPage();
expect("server fetched the async value once", fetches, 1);
expect("server HTML has the resolved async value", html.includes("greeting from the server"), true);
expect("onSettled doesn't run on the server", html.includes(">rendering<"), true);

const { server, origin } = await serve({ "/": html, "/client.js": clientBundle });
const browser = await launch();
try {
  const tab = await browser.newPage();
  const problems = watchProblems(tab);
  await tab.goto(origin);
  await tab.waitForSelector("#app[data-hydrated]", { timeout: 5000 });

  const reused = await tab.evaluate(() => {
    const all = Array.from(document.querySelectorAll("#app *"));
    return { total: all.length, fromServer: all.filter((el) => el.__ssr === true).length };
  });
  expect("every element was claimed, none recreated", reused.fromServer, reused.total);
  expect("client did not refetch the serialized async value", await tab.$("#app[data-fetched]"), null);
  expect("async value shows after hydration", await tab.textContent("#greeting"), "greeting from the server");
  expect("onSettled runs once hydrated", await tab.textContent("#settled"), "settled");

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
report();
