import { cp, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";

const root = process.cwd();
const source = join(root, "dist", "examples", "solid-start-ssr-client.js");
const destination = join(root, "src", "Examples", "SolidStartSSR", "public", "client.js");

await mkdir(dirname(destination), { recursive: true });
await cp(source, destination);

console.log(`[copy-solid-start-ssr-client] copied ${source} -> ${destination}`);
