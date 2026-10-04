// Renders Test.Compiled.Fixture through the runtime path and through compiled
// templates (`vite/compile.mjs`), from purs and purs-backend-es output: in the
// browser, on the server, and hydrated. Both modes are driven the same way and
// must give the same DOM.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { env } from "node:process";
import { pathToFileURL } from "node:url";
import { checks, launch, rootDir, run, serve, watchProblems } from "../support.mjs";

const { expect: check, report } = checks("compiled");
const modes = ["runtime", "compiled"];

run("purs-backend-es", ["build"]);
for (const output of ["output", "output-es"]) {
const build = (mode, target) => {
  env.PURS_SOLID_OUTPUT = output;
  env.PURS_SOLID_VIEWS = mode;
  env.PURS_SOLID_TARGET = target;
  run("vite", ["build", "--config", join(rootDir, "test", "compiled", "vite.config.mjs")]);
  return join(rootDir, "dist", "compiled", output, `${mode}-${target}`, target === "server" ? "server.js" : "app.js");
};
const bundles = {};
for (const mode of modes) for (const target of ["client", "hydrate", "server"]) bundles[`${mode}-${target}`] = build(mode, target);
const expect = (label, actual, expected) => check(`${output}: ${label}`, actual, expected);
expect("the compiled bundle has Solid templates", readFileSync(bundles["compiled-client"], "utf8").includes("<main"), true);

// The first difference between two snapshots, with some context, or `null`.
const difference = (actual, expected) => {
  const [a, e] = [JSON.stringify(actual), JSON.stringify(expected)];
  if (a === e) return null;
  let at = 0;
  while (a[at] === e[at]) at += 1;
  return { expected: e.slice(Math.max(0, at - 60), at + 60), got: a.slice(Math.max(0, at - 60), at + 60) };
};

const pages = {};
for (const mode of modes) {
  const { render } = await import(pathToFileURL(bundles[`${mode}-server`]).href);
  const { body, script } = render();
  pages[`${mode}-client`] = `<!doctype html><html><head><meta charset="utf-8"></head><body><div id="app"></div><script type="module" src="/${mode}-client.js"></script></body></html>`;
  pages[`${mode}-server`] = `<!doctype html><html><head><meta charset="utf-8"></head><body><div id="app">${body}</div></body></html>`;
  pages[`${mode}-hydrate`] = `<!doctype html><html><head><meta charset="utf-8">${script}</head><body><div id="app">${body}</div>` +
    `<script>for (const el of document.querySelectorAll("#app *")) el.__ssr = true;</script><script type="module" src="/${mode}-hydrate.js"></script></body></html>`;
}

// Elements with sorted attributes, class tokens and style declarations (the
// paths set them in different orders), merged text, no comments or hydration keys.
const snapshot = (tab) =>
  tab.evaluate(() => {
    const value = (a) =>
      a.name === "class" ? a.value.split(/\s+/).filter(Boolean).sort().join(" ")
      : a.name === "style" ? a.value.split(";").map((d) => d.trim()).filter(Boolean).sort().join("; ")
      : a.value;
    const walk = (node) => {
      if (node.nodeType === 3) return node.nodeValue;
      if (node.nodeType !== 1) return "";
      const attrs = [...node.attributes]
        .filter((a) => a.name !== "_hk" && a.name !== "data-hydrated")
        .map((a) => `${a.name}=${JSON.stringify(value(a))}`)
        .sort()
        .join(" ");
      const children = [...node.childNodes].map(walk).join("");
      const ns = node.namespaceURI === "http://www.w3.org/2000/svg" ? "svg:" : "";
      return `<${ns}${node.localName}${attrs ? " " + attrs : ""}>${children}</${node.localName}>`;
    };
    const name = document.getElementById("name");
    const done = document.getElementById("done");
    return { html: walk(document.getElementById("app")), name: name?.value, done: done?.checked };
  });

const steps = [
  ["initial", async () => {}],
  ["click +1", (tab) => tab.click("#inc")],
  ["type a name", (tab) => tab.fill("#name", "grace")],
  ["check done", (tab) => tab.click("#done")],
  ["custom event", (tab) => tab.evaluate(() => document.querySelector("[role=status]").dispatchEvent(new Event("ping")))],
  ["click +1 again", (tab) => tab.click("#inc")],
];

const routes = {};
for (const [key, html] of Object.entries(pages)) routes[`/${key}`] = html;
for (const mode of modes) for (const target of ["client", "hydrate"]) routes[`/${mode}-${target}.js`] = bundles[`${mode}-${target}`];
const { server, origin } = await serve(routes);
const browser = await launch();
try {
  const drive = async (page, ready) => {
    const tab = await browser.newPage();
    const problems = watchProblems(tab);
    await tab.goto(`${origin}/${page}`);
    await tab.waitForSelector(ready);
    const reused = await tab.evaluate(() => {
      const all = [...document.querySelectorAll("#app *")];
      return all.every((el) => el.__ssr === true);
    });
    const snapshots = [];
    for (const [, step] of steps) {
      await step(tab);
      snapshots.push(await snapshot(tab));
    }
    await tab.close();
    return { snapshots, problems, reused };
  };
  const results = {};
  for (const mode of modes) {
    results[`${mode}-client`] = await drive(`${mode}-client`, "#fixture");
    results[`${mode}-hydrate`] = await drive(`${mode}-hydrate`, "#app[data-hydrated]");
    const tab = await browser.newPage();
    await tab.goto(`${origin}/${mode}-server`);
    results[`${mode}-server`] = await snapshot(tab);
    await tab.close();
  }
  for (const mode of modes) {
    expect(`${mode}: no page errors or warnings`, results[`${mode}-client`].problems, []);
    expect(`${mode}: hydrates without errors, mismatches or warnings`, results[`${mode}-hydrate`].problems, []);
    expect(`${mode}: hydration claims every server-rendered element`, results[`${mode}-hydrate`].reused, true);
  }
  expect("same server HTML", difference(results["compiled-server"], results["runtime-server"]), null);
  for (const target of ["client", "hydrate"]) {
    steps.forEach(([name], i) =>
      expect(`${target}: same DOM after ${name}`, difference(results[`compiled-${target}`].snapshots[i], results[`runtime-${target}`].snapshots[i]), null));
  }
} finally {
  await browser.close();
  server.close();
}
}
report();
