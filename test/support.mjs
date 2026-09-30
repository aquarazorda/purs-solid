import { execFileSync } from "node:child_process";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { delimiter, join } from "node:path";
import { cwd, env } from "node:process";

export const rootDir = cwd();

export const run = (command, args) =>
  execFileSync(command, args, {
    stdio: "inherit",
    env: { ...env, PATH: `${join(rootDir, "node_modules", ".bin")}${delimiter}${env.PATH}` },
  });

export const bundle = (module, outfile) =>
  run("spago", ["bundle", "-p", "purs-solid-examples", "--module", module, "--bundle-type", "app", "--platform", "browser", "--minify", "--outfile", outfile]);

export const page = (script) =>
  `<!doctype html><html><head><meta charset="utf-8"></head><body><div id="main"></div><script src="${script}"></script></body></html>`;

// `routes` maps a URL path to a file path, or to a string served as HTML.
export const serve = (routes) =>
  new Promise((resolve) => {
    const server = createServer(async (request, response) => {
      const route = routes[request.url.split("?")[0]];
      if (route === undefined) return void response.writeHead(404).end();
      const isFile = route.endsWith(".js");
      response.writeHead(200, { "content-type": isFile ? "text/javascript; charset=utf-8" : "text/html; charset=utf-8" });
      response.end(isFile ? await readFile(route) : route);
    });
    server.listen(0, "127.0.0.1", () => resolve({ server, origin: `http://127.0.0.1:${server.address().port}` }));
  });

export const launch = async () => (await import("playwright")).chromium.launch();

export const watchProblems = (tab) => {
  const problems = [];
  tab.on("pageerror", (error) => problems.push(error.message));
  tab.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") problems.push(message.text());
  });
  return problems;
};

export const checks = (name) => {
  let count = 0;
  const failures = [];
  return {
    expect(label, actual, expected) {
      count += 1;
      if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        failures.push(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
      }
    },
    report() {
      if (failures.length > 0) {
        console.error(`[${name}] ${failures.length} of ${count} checks failed:\n${failures.map((f) => `  - ${f}`).join("\n")}`);
        process.exitCode = 1;
      } else {
        console.log(`[${name}] passed ${count} checks`);
      }
    },
  };
};
