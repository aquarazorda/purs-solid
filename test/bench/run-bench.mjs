// npm run bench -- [label] [--reference] [--runs=N]
//
// Times each operation from the click until Solid's updates have flushed and
// layout is forced, in headless Chromium. --reference measures the same app in
// plain Solid 2 JSX. Writes docs/benchmarks/<label>.json.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { argv, versions } from "node:process";
import { brotliCompressSync, gzipSync } from "node:zlib";
import { bundle, launch, page, rootDir, run, serve } from "../support.mjs";

const args = argv.slice(2);
const reference = args.includes("--reference");
const label = args.find((arg) => !arg.startsWith("--")) ?? (reference ? "reference" : "purs-solid");
const runs = Number(args.find((arg) => arg.startsWith("--runs="))?.slice("--runs=".length) ?? 1);
const bundlePath = join(rootDir, "dist", reference ? "bench-reference" : "bench", "bench.js");

const scenarios = [
  { name: "create 1k rows", setup: ["clear"], timed: "run", check: { rows: 1000 } },
  { name: "replace 1k rows", setup: ["run"], timed: "run", check: { rows: 1000 } },
  { name: "update every 10th row", setup: ["run"], timed: "update", check: { rows: 1000, firstLabelSuffix: " !!!" } },
  { name: "swap rows", setup: ["run"], timed: "swaprows", check: { rows: 1000, swapped: true } },
  { name: "select row", setup: ["run"], timedSelector: "#tbody tr:nth-child(2) td:nth-child(2) a", check: { rows: 1000, selectedIndex: 1 } },
  { name: "append 1k rows", setup: ["run"], timed: "add", check: { rows: 2000 } },
  { name: "clear 1k rows", setup: ["run"], timed: "clear", check: { rows: 0 } },
  { name: "create 10k rows", setup: ["clear"], timed: "runlots", check: { rows: 10000 }, warmup: 1, samples: 5 },
];

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
};

const round = (value) => Math.round(value * 100) / 100;

const sample = (tab, scenario) =>
  tab.evaluate(async ({ setup, timed, timedSelector }) => {
    const frame = () => new Promise((resolve) => requestAnimationFrame(() => setTimeout(resolve, 0)));
    const task = () =>
      new Promise((resolve) => {
        const channel = new MessageChannel();
        channel.port1.onmessage = () => resolve();
        channel.port2.postMessage(null);
      });
    const rowIds = () => Array.from(document.querySelectorAll("#tbody tr td:first-child"), (td) => td.textContent);

    for (const id of setup) {
      document.getElementById(id).click();
      await frame();
    }
    const before = rowIds();
    const target = timedSelector ? document.querySelector(timedSelector) : document.getElementById(timed);
    const t0 = performance.now();
    target.click();
    await task();
    void document.body.offsetHeight;
    const elapsed = performance.now() - t0;
    await frame();
    const after = rowIds();
    return {
      elapsed,
      rows: after.length,
      firstLabel: document.querySelector("#tbody tr td:nth-child(2) a")?.textContent ?? null,
      swapped: before.length > 998 && after[1] === before[998] && after[998] === before[1],
      selected: Array.from(document.querySelectorAll("#tbody tr"), (tr, i) => (tr.classList.contains("danger") ? i : -1)).filter((i) => i >= 0),
    };
  }, scenario);

const verify = ({ name, check }, result) => {
  const fail = (message) => {
    throw new Error(`${name}: ${message}`);
  };
  if (result.rows !== check.rows) fail(`expected ${check.rows} rows, got ${result.rows}`);
  if (check.firstLabelSuffix && !result.firstLabel?.endsWith(check.firstLabelSuffix)) fail(`first label not updated (${result.firstLabel})`);
  if (check.selectedIndex !== undefined && result.selected.join() !== String(check.selectedIndex)) fail(`selected ${JSON.stringify(result.selected)}`);
  if (check.swapped && !result.swapped) fail("rows 1 and 998 were not swapped");
};

const measure = async (tab, scenario) => {
  const warmup = scenario.warmup ?? 3;
  const timings = [];
  for (let i = 0; i < warmup + (scenario.samples ?? 10); i += 1) {
    const result = await sample(tab, scenario);
    verify(scenario, result);
    if (i >= warmup) timings.push(result.elapsed);
  }
  return { median: median(timings), min: Math.min(...timings) };
};

if (reference) run("vite", ["build", "--config", join(rootDir, "test", "bench", "reference", "vite.config.mjs")]);
else bundle("Bench.Rows", bundlePath);

const code = await readFile(bundlePath);
const { server, origin } = await serve({ "/": page("/bench.js"), "/bench.js": bundlePath });
const browser = await launch();
try {
  const errors = [];
  const perRun = [];
  for (let i = 0; i < runs; i += 1) {
    const tab = await browser.newPage();
    tab.on("pageerror", (error) => errors.push(error.message));
    await tab.goto(origin);
    await tab.waitForSelector("#run");
    const results = {};
    for (const scenario of scenarios) results[scenario.name] = await measure(tab, scenario);
    perRun.push(results);
    await tab.close();
  }
  if (errors.length > 0) throw new Error(`Page errors:\n${errors.join("\n")}`);

  const operations = {};
  for (const { name } of scenarios) {
    const all = perRun.map((results) => results[name]);
    operations[name] = { median: round(median(all.map((r) => r.median))), min: round(Math.min(...all.map((r) => r.min))) };
    console.log(`${name.padEnd(24)} ${String(operations[name].median).padStart(8)} ms`);
  }

  const bundleBytes = { minified: code.length, gzip: gzipSync(code, { level: 9 }).length, brotli: brotliCompressSync(code).length };
  const solid = JSON.parse(await readFile(join(rootDir, "node_modules", "solid-js", "package.json"), "utf8")).version;
  const report = { label, date: new Date().toISOString(), solid, node: versions.node, chromium: browser.version(), runs, bundleBytes, operations };
  await mkdir(join(rootDir, "docs", "benchmarks"), { recursive: true });
  await writeFile(join(rootDir, "docs", "benchmarks", `${label}.json`), JSON.stringify(report, null, 2) + "\n");
  console.log(`bundle: ${bundleBytes.minified} B minified, ${bundleBytes.gzip} B gzip, ${bundleBytes.brotli} B brotli`);
} finally {
  await browser.close();
  server.close();
}
