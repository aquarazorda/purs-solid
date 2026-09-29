// Rows benchmark runner (js-framework-benchmark style) for `Bench.Rows`.
//
// Usage: npm run bench -- [label]
//   Bundles Bench.Rows as a minified production build, measures bundle size and
//   the time from click to next frame for each operation in headless Chromium,
//   and writes docs/benchmarks/<label>.json (default label: "current").

import { execFileSync } from "node:child_process";
import { createServer } from "node:http";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { delimiter, extname, join, normalize } from "node:path";
import { argv, cwd, env, versions } from "node:process";
import { brotliCompressSync, gzipSync } from "node:zlib";

const rootDir = cwd();
const label = argv[2] ?? "current";
const bundlePath = join(rootDir, "dist", "bench", "bench.js");

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
};

const bundle = () => {
  execFileSync(
    "spago",
    [
      "bundle",
      "--module", "Bench.Rows",
      "--bundle-type", "app",
      "--platform", "browser",
      "--minify",
      "--outfile", bundlePath,
    ],
    // `spago bundle` needs the locally installed esbuild on PATH.
    { stdio: "inherit", env: { ...env, PATH: `${join(rootDir, "node_modules", ".bin")}${delimiter}${env.PATH}` } }
  );
};

const serve = () =>
  new Promise((resolve, reject) => {
    const server = createServer(async (request, response) => {
      const path = normalize(join(rootDir, decodeURIComponent((request.url ?? "/").split("?")[0])));
      if (!path.startsWith(normalize(rootDir))) {
        response.writeHead(403).end();
        return;
      }
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

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
};

const round = (value) => Math.round(value * 100) / 100;

// Each scenario: optional untimed setup, the timed button, and a check that the work happened.
const scenarios = [
  { name: "create 1k rows", setup: ["clear"], timed: "run", check: { rows: 1000 } },
  { name: "replace 1k rows", setup: ["run"], timed: "run", check: { rows: 1000 } },
  { name: "update every 10th row", setup: ["run"], timed: "update", check: { rows: 1000, firstLabelSuffix: " !!!" } },
  { name: "swap rows", setup: ["run"], timed: "swaprows", check: { rows: 1000, swapped: true } },
  { name: "append 1k rows", setup: ["run"], timed: "add", check: { rows: 2000 } },
  { name: "clear 1k rows", setup: ["run"], timed: "clear", check: { rows: 0 } },
  { name: "create 10k rows", setup: ["clear"], timed: "runlots", check: { rows: 10000 }, warmup: 1, samples: 5 },
];

const measure = async (page, scenario) => {
  const warmup = scenario.warmup ?? 3;
  const samples = scenario.samples ?? 10;
  const timings = [];

  for (let i = 0; i < warmup + samples; i += 1) {
    const result = await page.evaluate(async ({ setup, timed }) => {
      const frame = () => new Promise((resolve) => requestAnimationFrame(() => setTimeout(resolve, 0)));
      const click = (id) => document.getElementById(id).click();
      const rowIds = () => Array.from(document.querySelectorAll("#tbody tr td:first-child"), (td) => td.textContent);

      for (const id of setup) {
        click(id);
        await frame();
      }

      const before = rowIds();
      const t0 = performance.now();
      click(timed);
      await frame();
      const elapsed = performance.now() - t0;
      const after = rowIds();
      const firstLabel = document.querySelector("#tbody tr td:nth-child(2) a")?.textContent ?? null;

      return {
        elapsed,
        rows: after.length,
        firstLabel,
        swapped: before.length > 998 && after[1] === before[998] && after[998] === before[1],
      };
    }, scenario);

    const { check } = scenario;
    if (result.rows !== check.rows) {
      throw new Error(`${scenario.name}: expected ${check.rows} rows, got ${result.rows}`);
    }
    if (check.firstLabelSuffix && !result.firstLabel?.endsWith(check.firstLabelSuffix)) {
      throw new Error(`${scenario.name}: first label not updated (${result.firstLabel})`);
    }
    if (check.swapped && !result.swapped) {
      throw new Error(`${scenario.name}: rows 1 and 998 were not swapped`);
    }

    if (i >= warmup) {
      timings.push(result.elapsed);
    }
  }

  return { median: round(median(timings)), min: round(Math.min(...timings)), samples: timings.length };
};

const main = async () => {
  bundle();

  const code = await readFile(bundlePath);
  const size = {
    minified: code.length,
    gzip: gzipSync(code, { level: 9 }).length,
    brotli: brotliCompressSync(code).length,
  };

  const { chromium } = await import("playwright");
  const server = await serve();
  const browser = await chromium.launch();

  try {
    const page = await browser.newPage();
    const pageErrors = [];
    page.on("pageerror", (error) => pageErrors.push(error.message));

    await page.goto(`http://127.0.0.1:${server.address().port}/test/bench/index.html`);
    await page.waitForSelector("#run");

    const probe = await page.$eval("#reactive-attr-probe", (input) => input.value);

    const results = {};
    for (const scenario of scenarios) {
      results[scenario.name] = await measure(page, scenario);
      console.log(`${scenario.name.padEnd(24)} median ${String(results[scenario.name].median).padStart(8)} ms`);
    }

    if (pageErrors.length > 0) {
      throw new Error(`Page errors:\n${pageErrors.join("\n")}`);
    }

    const solidVersion = JSON.parse(await readFile(join(rootDir, "node_modules", "solid-js", "package.json"), "utf8")).version;
    const report = {
      label,
      date: new Date().toISOString(),
      solid: solidVersion,
      node: versions.node,
      chromium: browser.version(),
      bundleBytes: size,
      reactiveAttributeProbe: probe,
      operations: results,
    };

    await mkdir(join(rootDir, "docs", "benchmarks"), { recursive: true });
    await writeFile(join(rootDir, "docs", "benchmarks", `${label}.json`), JSON.stringify(report, null, 2) + "\n");

    console.log(`bundle: ${size.minified} B minified, ${size.gzip} B gzip, ${size.brotli} B brotli`);
    console.log(`reactive attribute probe value: ${JSON.stringify(probe)}`);
    console.log(`wrote docs/benchmarks/${label}.json`);
  } finally {
    await browser.close();
    server.close();
  }
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
