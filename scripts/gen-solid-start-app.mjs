import { promises as fs } from "node:fs";
import path from "node:path";
import process from "node:process";

const projectRoot = process.cwd();
const hostRoot = path.join(projectRoot, "src", "Examples", "SolidStart", "Host");
const routesRoot = path.join(projectRoot, "src", "Examples", "SolidStart", "Routes");
const appRoot = path.join(projectRoot, "examples", "solid-start");

const modulePattern = /^\s*module\s+([A-Za-z0-9_'.]+)\s+where/m;

const isParamSegment = (segment) => /^\[[A-Za-z0-9_]+\]$/.test(segment);
const isCatchAllSegment = (segment) => /^\[\.\.\.[A-Za-z0-9_]+\]$/.test(segment);
const isOptionalSegment = (segment) => /^\[\[[A-Za-z0-9_]+\]\]$/.test(segment);
const isLowercaseStaticSegment = (segment) => /^[a-z0-9-]+$/.test(segment);

const toPosixPath = (filePath) => filePath.split(path.sep).join("/");

const stripPursExtension = (relativePath) => relativePath.replace(/\.purs$/, "");

const toRouteSegments = (relativeNoExtension) => {
  const rawSegments = relativeNoExtension.split("/").filter(Boolean);
  if (rawSegments.length === 0) {
    return [];
  }

  if (rawSegments[rawSegments.length - 1] === "index") {
    rawSegments.pop();
  }

  return rawSegments;
};

const segmentToDescriptor = (segment) => {
  if (isCatchAllSegment(segment)) {
    return { kind: "catchAll", value: segment.slice(4, -1) };
  }

  if (isOptionalSegment(segment)) {
    return { kind: "optional", value: segment.slice(2, -2) };
  }

  if (isParamSegment(segment)) {
    return { kind: "param", value: segment.slice(1, -1) };
  }

  if (!isLowercaseStaticSegment(segment)) {
    throw new Error(
      `Route segment '${segment}' must be lowercase (a-z, 0-9, -). ` +
        "Use lowercase file and folder names in src/Examples/SolidStart/Routes."
    );
  }

  return { kind: "static", value: segment };
};

async function pathExistsAsDirectory(target) {
  try {
    const stat = await fs.stat(target);
    return stat.isDirectory();
  } catch {
    return false;
  }
}

async function walkFiles(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const nested = await walkFiles(fullPath);
      files.push(...nested);
    } else if (entry.isFile()) {
      files.push(fullPath);
    }
  }

  return files;
}

async function walkPursFiles(dir) {
  const files = await walkFiles(dir);
  return files.filter((filePath) => filePath.endsWith(".purs"));
}

async function copyTree(sourceRoot, destinationRoot) {
  const files = await walkFiles(sourceRoot);

  for (const sourcePath of files) {
    const relativePath = path.relative(sourceRoot, sourcePath);
    const destinationPath = path.join(destinationRoot, relativePath);
    await fs.mkdir(path.dirname(destinationPath), { recursive: true });
    const content = await fs.readFile(sourcePath);
    await fs.writeFile(destinationPath, content);
  }
}

async function resetGeneratedAppTree() {
  const generatedPaths = [
    path.join(appRoot, "src"),
    path.join(appRoot, "public"),
    path.join(appRoot, "README.md"),
    path.join(appRoot, "package.json"),
    path.join(appRoot, "vite.config.js"),
    path.join(appRoot, "vite.config.ts"),
    path.join(appRoot, "tsconfig.json"),
    path.join(appRoot, "index.html"),
    path.join(appRoot, "solid-start.css"),
    path.join(appRoot, "counter"),
    path.join(appRoot, "todomvc"),
  ];

  for (const generatedPath of generatedPaths) {
    await fs.rm(generatedPath, { recursive: true, force: true });
  }

  await fs.mkdir(appRoot, { recursive: true });
}

function parseModuleName(fileContent, filePath) {
  const match = fileContent.match(modulePattern);
  if (!match) {
    throw new Error(`Missing module declaration in ${filePath}`);
  }

  return match[1];
}

function renderRouteHelper() {
  return [
    "const normalizeString = (value) => (typeof value === \"string\" ? value : \"\");",
    "",
    "const encodePathSegment = (value) => encodeURIComponent(value);",
    "",
    "export const routePathFromProps = (segments, props) => {",
    "  const params = props?.params ?? {};",
    "  const pathSegments = [];",
    "",
    "  for (const segment of segments) {",
    "    if (segment.kind === \"static\") {",
    "      pathSegments.push(segment.value);",
    "      continue;",
    "    }",
    "",
    "    if (segment.kind === \"param\") {",
    "      const raw = normalizeString(params[segment.value]);",
    "      if (raw.length === 0) {",
    "        return \"/\";",
    "      }",
    "      pathSegments.push(encodePathSegment(raw));",
    "      continue;",
    "    }",
    "",
    "    if (segment.kind === \"optional\") {",
    "      const raw = normalizeString(params[segment.value]);",
    "      if (raw.length > 0) {",
    "        pathSegments.push(encodePathSegment(raw));",
    "      }",
    "      continue;",
    "    }",
    "",
    "    if (segment.kind === \"catchAll\") {",
    "      const raw = normalizeString(params[segment.value]);",
    "      if (raw.length > 0) {",
    "        const pieces = raw.split(\"/\").filter(Boolean);",
    "        for (const piece of pieces) {",
    "          pathSegments.push(encodePathSegment(piece));",
    "        }",
    "      }",
    "    }",
    "  }",
    "",
    "  return pathSegments.length === 0 ? \"/\" : `/${pathSegments.join(\"/\")}`;",
    "};",
    "",
  ].join("\n");
}

function importPathFromTo(fromFile, toFile) {
  const relativePath = toPosixPath(path.relative(path.dirname(fromFile), toFile));
  if (relativePath.startsWith(".")) {
    return relativePath;
  }

  return `./${relativePath}`;
}

function renderRouteWrapper(routeSegments, helperImportPath) {
  return [
    "import { element } from \"#purs/Solid.Component/index.js\";",
    "import { appWithRoute } from \"#purs/Examples.SolidStart.App/index.js\";",
    `import { routePathFromProps } from \"${helperImportPath}\";`,
    "",
    `const routeSegments = ${JSON.stringify(routeSegments, null, 2)};`,
    "",
    "export default function RoutePage(props) {",
    "  const routePath = routePathFromProps(routeSegments, props);",
    "  return element(appWithRoute(routePath))({});",
    "}",
    "",
  ].join("\n");
}

async function generateRoutes() {
  const hasRoutesDirectory = await pathExistsAsDirectory(routesRoot);
  if (!hasRoutesDirectory) {
    throw new Error("Routes root not found at src/Examples/SolidStart/Routes");
  }

  const routeFiles = await walkPursFiles(routesRoot);
  if (routeFiles.length === 0) {
    throw new Error("No route files found under src/Examples/SolidStart/Routes");
  }

  const helperPath = path.join(appRoot, "src", "_purs_route.js");
  await fs.mkdir(path.dirname(helperPath), { recursive: true });
  await fs.writeFile(helperPath, renderRouteHelper(), "utf8");

  let generatedCount = 0;
  for (const absoluteFilePath of routeFiles) {
    const content = await fs.readFile(absoluteFilePath, "utf8");
    parseModuleName(content, absoluteFilePath);

    const relativePath = toPosixPath(path.relative(routesRoot, absoluteFilePath));
    const relativeNoExtension = stripPursExtension(relativePath);
    const segments = toRouteSegments(relativeNoExtension).map(segmentToDescriptor);

    const outputPath = path.join(appRoot, "src", "routes", relativeNoExtension + ".jsx");
    const helperImportPath = importPathFromTo(outputPath, helperPath);
    const wrapper = renderRouteWrapper(segments, helperImportPath);

    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    await fs.writeFile(outputPath, wrapper, "utf8");
    generatedCount += 1;
  }

  return generatedCount;
}

async function writeStartCompatibilityFiles() {
  const entryServerTsxPath = path.join(appRoot, "src", "entry-server.tsx");
  const content = "export { default } from \"./entry-server.jsx\";\n";
  await fs.mkdir(path.dirname(entryServerTsxPath), { recursive: true });
  await fs.writeFile(entryServerTsxPath, content, "utf8");
}

async function main() {
  await resetGeneratedAppTree();
  await copyTree(hostRoot, appRoot);
  const routeFileCount = await generateRoutes();
  await writeStartCompatibilityFiles();

  console.log(
    `[gen-solid-start-app] wrote generated app to examples/solid-start with ${routeFileCount} route wrapper(s)`
  );
}

main().catch((error) => {
  console.error("[gen-solid-start-app] failed:", error);
  process.exitCode = 1;
});
