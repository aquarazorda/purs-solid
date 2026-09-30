// The purs-solid/vite plugin's own logic, without a Vite build.
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import pursSolid from "purs-solid/vite";
import { checks } from "../support.mjs";

const { expect, report } = checks("vite-plugin");

const workspace = (spago, modules) => {
  const root = mkdtempSync(join(tmpdir(), "purs-solid-vite-"));
  writeFileSync(join(root, "spago.yaml"), spago);
  for (const [dir, module] of Object.entries(modules)) {
    mkdirSync(join(root, dir, module), { recursive: true });
    writeFileSync(join(root, dir, module, "index.js"), "export const app = () => null;\n");
  }
  return root;
};

const configure = (options, root) => {
  const [plugin] = pursSolid(options);
  try {
    plugin.config({ root });
    return readFileSync(join(root, "node_modules", ".purs-solid", "app.js"), "utf8");
  } catch (error) {
    return error.message;
  }
};

const plain = workspace("workspace:\n  packageSet:\n    registry: 1.0.0\n", { output: "App" });
expect(
  "start.app defaults to the module App",
  configure({ start: true, ssr: true }, plain),
  `export { app as default } from ${JSON.stringify(join(plain, "output", "App", "index.js"))};\n`
);
expect(
  "a named app module that isn't compiled fails clearly",
  configure({ start: { app: "Missing.App" } }, plain).startsWith("purs-solid/vite: start.app is Missing.App, but"),
  true
);

const es = workspace("workspace:\n  backend:\n    cmd: purs-backend-es\n", { "output-es": "App" });
expect("purs-backend-es output is output-es", configure({ start: true }, es).includes(join("output-es", "App")), true);

const serverTransform = (code, id, consumer) => {
  const [plugin] = pursSolid({ start: true });
  return plugin.transform.handler.call({ environment: { config: { consumer } } }, code, id);
};
const serverModule = `var greet = Solid_Start_ServerFunction.serverFunction()()(function (name) { return name; });
export {
    greet
};
export {
    useServer
} from "../Solid.Start.UseServer/index.js";
`;
const client = serverTransform(serverModule, "/app/output/App.Api/index.js", "client");
expect("a server module becomes a use server module", client.code.startsWith('"use server";'), true);
expect("its marker export is dropped", client.code.includes("useServer"), false);
expect("the client gets no export check", client.code.includes("purs-solid/server-function"), false);
const server = serverTransform(serverModule, "/app/output/App.Api/index.js", "server");
expect("the server checks each export is a server function", server.code.includes('"greet": greet'), true);
expect(
  "other modules are left alone",
  serverTransform("var x = 1;\nexport {\n    x\n};\n", "/app/output/App.Other/index.js", "client"),
  null
);

for (const root of [plain, es]) rmSync(root, { recursive: true, force: true });
report();
