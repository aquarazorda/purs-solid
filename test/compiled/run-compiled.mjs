// Renders Test.Compiled.Fixture through the runtime path and through compiled
// templates (`vite/compile.mjs`), drives both the same way, and compares the
// DOM after each step.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { env } from "node:process";
import { checks, launch, rootDir, run, serve, watchProblems } from "../support.mjs";

const { expect, report } = checks("compiled");

run("purs-backend-es", ["build"]);
const build = (mode) => {
  run("vite", ["build", "--config", join(rootDir, "test", "compiled", "vite.config.mjs")]);
  return join(rootDir, "dist", `compiled-${mode}`, "app.js");
};
env.PURS_SOLID_VIEWS = "runtime";
const runtimeBundle = build("runtime");
env.PURS_SOLID_VIEWS = "compiled";
const compiledBundle = build("compiled");
expect("the compiled bundle has Solid templates", readFileSync(compiledBundle, "utf8").includes("<main"), true);

const page = (script) => `<!doctype html><html><head><meta charset="utf-8"></head><body><div id="app"></div><script src="${script}"></script></body></html>`;

// Elements with sorted attributes, class tokens and style declarations (the
// two paths set them in different orders), merged text, no comments.
const snapshot = (tab) =>
  tab.evaluate(() => {
    const value = (a) =>
      a.name === "class" ? a.value.split(/\s+/).filter(Boolean).sort().join(" ")
      : a.name === "style" ? a.value.split(";").map((d) => d.trim()).filter(Boolean).sort().join("; ")
      : a.value;
    const walk = (node) => {
      if (node.nodeType === 3) return node.nodeValue;
      if (node.nodeType !== 1) return "";
      const attrs = [...node.attributes].map((a) => `${a.name}=${JSON.stringify(value(a))}`).sort().join(" ");
      const children = [...node.childNodes].map(walk).join("");
      const ns = node.namespaceURI === "http://www.w3.org/2000/svg" ? "svg:" : "";
      return `<${ns}${node.localName}${attrs ? " " + attrs : ""}>${children}</${node.localName}>`;
    };
    const app = document.getElementById("app");
    return {
      html: walk(app),
      name: document.getElementById("name").value,
      done: document.getElementById("done").checked,
    };
  });

const steps = [
  ["initial", async () => {}],
  ["click +1", (tab) => tab.click("#inc")],
  ["type a name", (tab) => tab.fill("#name", "grace")],
  ["check done", (tab) => tab.click("#done")],
  ["custom event", (tab) => tab.evaluate(() => document.querySelector("[role=status]").dispatchEvent(new Event("ping")))],
  ["click +1 again", (tab) => tab.click("#inc")],
];

const { server, origin } = await serve({ "/runtime": page("/runtime.js"), "/runtime.js": runtimeBundle, "/compiled": page("/compiled.js"), "/compiled.js": compiledBundle });
const browser = await launch();
try {
  const results = {};
  for (const mode of ["runtime", "compiled"]) {
    const tab = await browser.newPage();
    const problems = watchProblems(tab);
    await tab.goto(`${origin}/${mode}`);
    await tab.waitForSelector("#fixture");
    results[mode] = [];
    for (const [, step] of steps) {
      await step(tab);
      results[mode].push(await snapshot(tab));
    }
    expect(`${mode}: no page errors or warnings`, problems, []);
  }
  steps.forEach(([name], i) => expect(`same DOM after: ${name}`, results.compiled[i], results.runtime[i]));
} finally {
  await browser.close();
  server.close();
}
report();
