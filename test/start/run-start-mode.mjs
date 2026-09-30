import { spawn } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { env } from "node:process";
import { checks, launch, rootDir, run, watchProblems } from "../support.mjs";

const { expect, report } = checks("start-mode");
const host = join(rootDir, "examples", "src", "StartMode", "Host");
const dist = join(host, "dist");
run("vite", ["build", "--config", join(host, "vite.config.mjs"), "--logLevel", "warn"]);

const assets = join(dist, "client", "assets");
const clientFiles = (await readdir(assets)).filter((f) => f.endsWith(".js"));
const clientCode = (await Promise.all(clientFiles.map((f) => readFile(join(assets, f), "utf8")))).join("\n");
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

const browser = await launch();
try {
  const html = await (await fetch(origin)).text();
  expect("server-rendered greeting", html.includes("hello page, from the server"), true);

  const tab = await browser.newPage();
  const problems = watchProblems(tab);
  const serverCalls = [];
  tab.on("request", (request) => {
    if (request.url().includes("/_server")) serverCalls.push(request.url());
  });
  await tab.goto(origin, { waitUntil: "networkidle" });
  expect("hydrated greeting", await tab.textContent("#greeting"), "hello page, from the server");
  expect("no server call during hydration", serverCalls.length, 0);
  await tab.click("#ask");
  await tab.waitForFunction(() => document.querySelector("#reply").textContent !== "not asked", null, { timeout: 5000 });
  expect("server function reply", await tab.textContent("#reply"), "hello button, from the server");
  expect("one server call for the click", serverCalls.length, 1);
  expect("no page errors or warnings", problems, []);
} finally {
  await browser.close();
  server.kill();
}
report();
