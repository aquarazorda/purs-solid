// The start-mode example under `vite dev`, including PureScript edits while it
// runs: a changed server module and a newly added lazy component.
import { execFileSync } from "node:child_process";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createServer } from "vite";
import { checks, launch, rootDir, watchProblems } from "../support.mjs";

const { expect, report } = checks("dev-mode");
const example = join(rootDir, "examples", "src", "StartMode");

// Solid's server-side diagnostics, e.g. a lazy component it can't preload.
const diagnostics = [];
for (const level of ["log", "warn", "error"]) {
  const original = console[level];
  console[level] = (...args) => {
    const text = args.map(String).join(" ");
    if (/^\[[A-Z_]+\]/.test(text)) diagnostics.push(text.split("\n")[0]);
    original(...args);
  };
}

const build = () => execFileSync("spago", ["build"], { stdio: "ignore" });
const port = 5000 + Math.floor(Math.random() * 1000);
const origin = `http://localhost:${port}`;
const server = await createServer({
  configFile: join(example, "Host", "vite.config.mjs"),
  server: { port, strictPort: true },
  logLevel: "warn",
});
await server.listen();

// The page once `ready` holds for it, for edits that Vite picks up when it sees them.
const pageWhen = async (ready) => {
  for (let i = 0; i < 100; i += 1) {
    const response = await fetch(origin);
    const html = await response.text();
    if (ready(html) || i === 99) return { response, html };
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
};

const edits = {
  [join(example, "Api.purs")]: (code) => code.replace('"hello "', '"hi "'),
  [join(example, "App.purs")]: (code) =>
    code
      .replace(
        "    , Control.loading empty (Component.element footer {})\n",
        "    , Control.loading empty (Component.element footer {})\n    , Control.loading empty (Component.element badge {})\n"
      )
      .concat('\nbadge :: Component.Component {}\nbadge = Component.lazy @"Examples.StartMode.Badge.badge"\n'),
};
const badge = join(example, "Badge.purs");
const originals = Object.fromEntries(Object.keys(edits).map((file) => [file, readFileSync(file, "utf8")]));

const browser = await launch();
try {
  const first = await pageWhen(() => true);
  expect("middleware header", first.response.headers.get("x-middleware"), "purs-solid");
  expect("server-rendered greeting", first.html.includes("hello page, from the server"), true);
  expect("server-rendered lazy component", first.html.includes("loaded lazily"), true);

  const tab = await browser.newPage();
  const problems = watchProblems(tab);
  await tab.goto(origin, { waitUntil: "networkidle" });
  expect("hydrated greeting", await tab.textContent("#greeting"), "hello page, from the server");
  expect("hydrated lazy component", await tab.textContent("#footer"), "loaded lazily");
  await tab.click("#ask");
  await tab.waitForFunction(() => document.querySelector("#reply").textContent !== "not asked", null, { timeout: 10000 });
  expect("server function reply", await tab.textContent("#reply"), "hello button, from the server");

  for (const [file, edit] of Object.entries(edits)) writeFileSync(file, edit(originals[file]));
  writeFileSync(
    badge,
    [
      "module Examples.StartMode.Badge (badge) where",
      "",
      "import Prelude",
      "",
      "import Solid.Component as Component",
      "import Solid.DOM.HTML as H",
      "",
      "badge :: Component.Component {}",
      'badge = Component.component \\_ -> pure (H.p { id: "badge" } "added while running")',
      "",
    ].join("\n")
  );
  build();

  // The open page reloads itself once the build's output has settled.
  await tab.waitForSelector("#badge", { timeout: 15000 });
  await tab.waitForLoadState("networkidle");
  expect("the open page reloads with the new lazy component", await tab.textContent("#badge"), "added while running");
  expect("and the edited server module", await tab.textContent("#greeting"), "hi page, from the server");

  const edited = await pageWhen((html) => html.includes("hi page") && html.includes("added while running"));
  expect("an edited server module runs without a restart", edited.html.includes("hi page, from the server"), true);
  expect("a lazy component added while running renders on the server", edited.html.includes("added while running"), true);
  await tab.click("#ask");
  await tab.waitForFunction(() => document.querySelector("#reply").textContent !== "not asked", null, { timeout: 10000 });
  expect("the edited server function answers the client", await tab.textContent("#reply"), "hi button, from the server");
  expect("no page errors or warnings", problems, []);
  expect("no Solid diagnostics on the server", diagnostics, []);
} finally {
  for (const [file, code] of Object.entries(originals)) writeFileSync(file, code);
  rmSync(badge, { force: true });
  rmSync(join(rootDir, "output", "Examples.StartMode.Badge"), { recursive: true, force: true });
  build();
  await browser.close();
  await server.close();
}
report();
