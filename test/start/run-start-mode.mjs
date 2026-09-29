// Start-mode end-to-end: builds Examples.StartMode with @solidjs/vite-plugin
// (start + ssr + serverFunctions), runs the built Node server and checks in
// Chromium: SSR, hydration without refetch, a "use server" call from the
// browser, and that no server function body reached the client bundle.
//
//   npm run test:start

import { execFileSync, spawn } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { delimiter, join } from "node:path";
import { cwd, env } from "node:process";

const rootDir = cwd();
const host = join(rootDir, "src", "Examples", "StartMode", "Host");
const dist = join(host, "dist");
const pathEnv = { ...env, PATH: `${join(rootDir, "node_modules", ".bin")}${delimiter}${env.PATH}` };

execFileSync("vite", ["build", "--config", join(host, "vite.config.mjs"), "--logLevel", "warn"], { stdio: "inherit", env: pathEnv });

let checks = 0;
const failures = [];
const expect = (label, actual, expected) => {
  checks += 1;
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    failures.push(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
};

const clientFiles = (await readdir(join(dist, "client", "assets"))).filter((f) => f.endsWith(".js"));
const clientCode = (await Promise.all(clientFiles.map((f) => readFile(join(dist, "client", "assets", f), "utf8")))).join("\n");
expect("server function body is not in the client bundle", clientCode.includes("from ${"), false);

const port = 4000 + Math.floor(Math.random() * 1000);
const server = spawn("node", [join(dist, "server", "node.js")], { env: { ...env, PORT: String(port) }, stdio: "ignore" });
const origin = `http://127.0.0.1:${port}`;
for (let i = 0; i < 50; i += 1) {
  try {
    await fetch(origin);
    break;
  } catch {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

const { chromium } = await import("playwright");
const browser = await chromium.launch();
try {
  const html = await (await fetch(origin)).text();
  expect("server-rendered greeting", html.includes("hello page, from the server"), true);

  const page = await browser.newPage();
  const problems = [];
  const serverCalls = [];
  page.on("pageerror", (error) => problems.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") problems.push(message.text());
  });
  page.on("request", (request) => {
    if (request.url().includes("/_server")) serverCalls.push(request.url());
  });
  await page.goto(origin, { waitUntil: "networkidle" });
  expect("hydrated greeting", await page.textContent("#greeting"), "hello page, from the server");
  expect("no server call during hydration", serverCalls.length, 0);
  await page.click("#ask");
  await page.waitForFunction(() => document.querySelector("#reply").textContent !== "not asked", null, { timeout: 5000 });
  expect("server function reply", await page.textContent("#reply"), "hello button, from the server");
  expect("one server call for the click", serverCalls.length, 1);
  expect("no page errors or warnings", problems, []);
} finally {
  await browser.close();
  server.kill();
}

if (failures.length > 0) {
  console.error(`[start-mode] ${failures.length} of ${checks} checks failed:\n${failures.map((f) => `  - ${f}`).join("\n")}`);
  process.exitCode = 1;
} else {
  console.log(`[start-mode] passed ${checks} checks`);
}
