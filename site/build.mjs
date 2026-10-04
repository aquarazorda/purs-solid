// npm run build:site [-- --no-api]
//
// Prerenders site/src's pages to site/dist, bundles the landing page's demo
// for hydration, and adds the API reference (`spago docs`) under api/.
// Code samples are `-- region name` … `-- endregion` blocks of site/src, so
// everything the pages show has been compiled.

import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv } from "node:process";
import { pathToFileURL } from "node:url";
import { rootDir, run } from "../test/support.mjs";

const siteDir = join(rootDir, "site");
const outDir = join(siteDir, "dist");

const sources = (dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
    entry.isDirectory() ? sources(join(dir, entry.name)) : entry.name.endsWith(".purs") ? [join(dir, entry.name)] : []
  );

const regions = new Map();
for (const file of sources(join(siteDir, "src"))) {
  let current = null;
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const start = line.match(/^\s*-- region (\S+)$/);
    if (start) current = { name: start[1], lines: [] };
    else if (/^\s*-- endregion$/.test(line)) {
      if (regions.has(current.name)) throw new Error(`region ${current.name} is defined twice`);
      regions.set(current.name, current.lines);
      current = null;
    } else if (current) current.lines.push(line);
  }
}

const dedent = (lines) => {
  const indent = Math.min(...lines.filter((line) => line.trim()).map((line) => line.match(/^ */)[0].length));
  return lines.map((line) => line.slice(indent)).join("\n").trim();
};

const escape = (text) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const token = /("""[\s\S]*?"""|"(?:\\.|[^"\\\n])*")|(--.*)|\b(module|import|where|do|let|in|case|of|if|then|else|forall|type|data|newtype|instance|class|derive|as)\b|\b([A-Z][\w']*)\b|\b(\d+(?:\.\d+)?)\b/g;
const kinds = ["str", "com", "kw", "ty", "num"];

const highlight = (source) => {
  let html = "";
  let last = 0;
  for (const match of source.matchAll(token)) {
    html += escape(source.slice(last, match.index));
    const kind = kinds[match.slice(1).findIndex((group) => group !== undefined)];
    html += `<span class="${kind}">${escape(match[0])}</span>`;
    last = match.index + match[0].length;
  }
  return html + escape(source.slice(last));
};

const snippets = (name) => {
  const lines = regions.get(name);
  if (!lines) throw new Error(`no region ${name} in site/src`);
  return highlight(dedent(lines));
};

const { render } = await import(pathToFileURL(join(rootDir, "output", "Site.Prerender", "index.js")).href);
const pages = render(snippets)();

const icon = `data:image/svg+xml,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="7" fill="#2c5f9e"/><text x="16" y="23" font-family="monospace" font-size="20" font-weight="700" text-anchor="middle" fill="#fff">λ</text></svg>')}`;

const document = ({ title, description, root, body, head = "", scripts = "" }) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${description}">
<link rel="icon" href="${icon}">
<link rel="stylesheet" href="${root}style.css">
${head}
</head>
<body>
${body}
${scripts}
</body>
</html>
`;

rmSync(outDir, { recursive: true, force: true });
mkdirSync(join(outDir, "docs"), { recursive: true });
cpSync(join(siteDir, "style.css"), join(outDir, "style.css"));

writeFileSync(
  join(outDir, "index.html"),
  document({
    title: "purs-solid: Solid 2 for PureScript",
    description: "PureScript bindings for Solid 2, with types that reject incorrect code.",
    root: "",
    body: pages.landing,
    head: pages.hydration,
    scripts: '<script src="client.js"></script>',
  })
);
writeFileSync(
  join(outDir, "docs", "index.html"),
  document({
    title: "Docs · purs-solid",
    description: "A guide to purs-solid: components, reactivity, stores, async, routing, SSR and start mode.",
    root: "../",
    body: pages.docs,
  })
);

run("spago", ["bundle", "-p", "purs-solid-site", "--module", "Site.Client", "--bundle-type", "app", "--platform", "browser", "--minify", "--outfile", join(outDir, "client.js")]);

if (!argv.includes("--no-api")) {
  run("spago", ["docs"]);
  cpSync(join(rootDir, "generated-docs", "html"), join(outDir, "api"), { recursive: true });
}

console.log(`[site] ${regions.size} samples, pages written to ${outDir}`);
