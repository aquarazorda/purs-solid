import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import solid from "@solidjs/vite-plugin";
import { parseAst } from "vite";

const marker = "useServer";
const moduleName = /^[A-Z][\w']*(\.[A-Z][\w']*)*$/;
const compiledModule = /[\\/]output(-es)?[\\/]([^\\/]+)[\\/]index\.js$/;
const entries = { app: "app", middleware: "middleware" };

// The spago workspace's output directory: `output-es` when the workspace
// builds with purs-backend-es.
const findOutput = (from) => {
  for (let dir = path.resolve(from); ; dir = path.dirname(dir)) {
    const config = path.join(dir, "spago.yaml");
    if (existsSync(config) && /^workspace:/m.test(readFileSync(config, "utf8"))) {
      return path.join(dir, /purs-backend-es/.test(readFileSync(config, "utf8")) ? "output-es" : "output");
    }
    if (dir === path.dirname(dir)) throw new Error(`purs-solid/vite: no spago workspace above ${from}`);
  }
};

// Solid's start options take files inside the Vite root with a default export,
// so each PureScript entry gets a one-line module under node_modules.
const entryFile = (root, output, option, module) => {
  const compiled = path.join(output, module, "index.js");
  if (!existsSync(compiled)) throw new Error(`purs-solid/vite: start.${option} is ${module}, but ${compiled} does not exist`);
  const file = path.join(root, "node_modules", ".purs-solid", `${option}.js`);
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, `export { ${entries[option]} as default } from ${JSON.stringify(compiled)};\n`);
  return file;
};

const exportName = (node) => node.name ?? node.value;

// The public value exports of a compiled module, as export specifiers, when it
// re-exports `useServer`. purs output states both in its exports. purs-backend-es
// exports every top-level binding and drops re-exports, so they come from the
// module's CoreFn, with names escaped the way the backend escapes them.
const serverExports = (id, module, specifiers) => {
  if (!/[\\/]output-es[\\/]/.test(id)) {
    if (!specifiers.some((s) => s.reExport && exportName(s.exported) === marker)) return null;
    return specifiers.filter((s) => !s.reExport);
  }
  const corefn = path.join(path.dirname(path.dirname(path.dirname(id))), "output", module, "corefn.json");
  const { exports, reExports } = JSON.parse(readFileSync(corefn, "utf8"));
  if (!reExports["Solid.Start.UseServer"]?.includes(marker)) return null;
  return exports.map((name) => {
    const escaped = [name, `$$${name}`, name.replaceAll("'", "$p")];
    const found = specifiers.find((s) => !s.reExport && escaped.includes(exportName(s.exported)));
    if (!found) throw new Error(`purs-solid/vite: can't find the export ${module}.${name} in ${id}`);
    return found;
  });
};

// A server module becomes a `"use server"` module exporting only its public
// values. On the server each is checked to be a `serverFunction`, since the
// client only ever sees them as server references.
const markServerModule = (code, id, module, server) => {
  const statements = parseAst(code).body.filter((node) => node.type.startsWith("Export"));
  const specifiers = statements.flatMap((node) => (node.specifiers ?? []).map((s) => ({ ...s, reExport: !!node.source })));
  const exports = serverExports(id, module, specifiers);
  if (!exports) return null;
  let result = code;
  for (const node of statements.toReversed()) result = result.slice(0, node.start) + result.slice(node.end);
  result += `\nexport { ${exports.map((s) => code.slice(s.start, s.end)).join(", ")} };\n`;
  if (server) {
    const values = exports.map((s) => `${JSON.stringify(exportName(s.exported))}: ${s.local.name}`);
    result +=
      `for (const [name, value] of Object.entries({ ${values.join(", ")} })) {\n` +
      `  if (!value?.[Symbol.for("purs-solid/server-function")]) throw new Error(\`purs-solid: ${module}.\${name} is exported from a server module, so it must be a serverFunction\`);\n` +
      `}\n`;
  }
  return `"use server";\n${result}`;
};

// `@solidjs/vite-plugin` with PureScript defaults: server modules compiled
// from the spago output, server functions on in start mode, and `start.app`
// / `start.middleware` given as module names (`app` defaults to module `App`).
export default function pursSolid(options = {}) {
  const start = options.start === true ? {} : options.start;
  const serverFunctions = options.serverFunctions ?? (start ? true : undefined);
  const include = serverFunctions?.filter?.include ?? "src/**/*.{jsx,tsx,tsrx,ts,js,mjs,cjs}";
  const solidOptions = {
    ...options,
    ...(start ? { start: { ...start } } : {}),
    ...(serverFunctions
      ? {
          serverFunctions: {
            ...(serverFunctions === true ? {} : serverFunctions),
            filter: { ...serverFunctions.filter, include: [include, compiledModule].flat() },
          },
        }
      : {}),
  };

  const plugin = {
    name: "purs-solid",
    enforce: "pre",
    config(config) {
      if (!start) return;
      const root = path.resolve(config.root ?? process.cwd());
      const output = findOutput(root);
      const app = start.app ?? (existsSync(path.join(output, "App", "index.js")) ? "App" : undefined);
      for (const [option, module] of Object.entries({ app, middleware: start.middleware })) {
        if (module && moduleName.test(module)) solidOptions.start[option] = entryFile(root, output, option, module);
      }
    },
    transform: {
      filter: { id: compiledModule, code: /useServer|Solid\$dStart\$dServerFunction/ },
      handler(code, id) {
        const [, , module] = id.match(compiledModule);
        const result = markServerModule(code, id, module, this.environment.config.consumer === "server");
        return result && { code: result, map: null };
      },
    },
  };
  return [plugin, solid(solidOptions)];
}
