import { promises as fs } from "node:fs";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

const projectRoot = process.cwd();
const templateRoot = path.join(projectRoot, "examples", "solid-start");

const packageManagers = ["npm", "pnpm", "bun", "none"];

const printUsage = () => {
  console.log(
    [
      "Usage:",
      "  node scripts/create-solid-start-app.mjs [options] <target-directory>",
      "",
      "Options:",
      "  --dry-run                    Print files that would be written",
      "  --force                      Allow copying into an existing non-empty directory",
      "  --base-path <path>           Set base path metadata (default: /)",
      "  --asset-prefix <path>        Set asset prefix metadata (default: /)",
      "  --name <name>                Starter app name metadata (default: directory name)",
      "  --install                    Run dependency install after copy",
      "  --no-install                 Skip dependency install (default)",
      "  --package-manager <pm>       npm | pnpm | bun | none (default: npm)",
      "  --help                       Show this help",
    ].join("\n")
  );
};

const parseArgs = (argv) => {
  const positional = [];
  const options = {
    dryRun: false,
    force: false,
    basePath: "/",
    assetPrefix: "/",
    install: false,
    packageManager: "npm",
    name: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];

    if (token === "--help") {
      options.help = true;
      continue;
    }

    if (token === "--dry-run") {
      options.dryRun = true;
      continue;
    }

    if (token === "--force") {
      options.force = true;
      continue;
    }

    if (token === "--install") {
      options.install = true;
      continue;
    }

    if (token === "--no-install") {
      options.install = false;
      continue;
    }

    if (token === "--base-path") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Missing value for --base-path");
      }
      options.basePath = value;
      index += 1;
      continue;
    }

    if (token === "--asset-prefix") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Missing value for --asset-prefix");
      }
      options.assetPrefix = value;
      index += 1;
      continue;
    }

    if (token === "--package-manager") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Missing value for --package-manager");
      }
      options.packageManager = value;
      index += 1;
      continue;
    }

    if (token === "--name") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Missing value for --name");
      }
      options.name = value;
      index += 1;
      continue;
    }

    if (token.startsWith("-")) {
      throw new Error(`Unknown option: ${token}`);
    }

    positional.push(token);
  }

  if (!options.help && positional.length !== 1) {
    throw new Error("Expected exactly one <target-directory> argument");
  }

  return {
    ...options,
    target: positional[0] ?? null,
  };
};

const ensureTemplateExists = async () => {
  try {
    const stat = await fs.stat(templateRoot);
    if (!stat.isDirectory()) {
      throw new Error("Template root is not a directory");
    }
  } catch {
    throw new Error(`Template root not found: ${path.relative(projectRoot, templateRoot)}`);
  }
};

const assertValidPrefix = (label, value) => {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${label} must be a non-empty string`);
  }

  if (!value.startsWith("/")) {
    throw new Error(`${label} must start with '/': ${value}`);
  }
};

const assertValidPackageManager = (value) => {
  if (!packageManagers.includes(value)) {
    throw new Error(`Unsupported package manager '${value}'. Expected one of: ${packageManagers.join(", ")}`);
  }
};

const assertTargetIsWritable = async (targetAbsolute, force) => {
  try {
    const stat = await fs.stat(targetAbsolute);
    if (!stat.isDirectory()) {
      throw new Error("Target path exists and is not a directory");
    }

    const entries = await fs.readdir(targetAbsolute);
    if (entries.length > 0 && !force) {
      throw new Error("Target directory already exists and is not empty (use --force to allow overwrite)");
    }
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return;
    }

    throw error;
  }
};

const walkFiles = async (dir) => {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const absolutePath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const nested = await walkFiles(absolutePath);
      files.push(...nested);
      continue;
    }

    if (entry.isFile()) {
      files.push(absolutePath);
    }
  }

  return files;
};

const copyTemplate = async (targetAbsolute, dryRun) => {
  const templateFiles = await walkFiles(templateRoot);

  for (const sourceAbsolute of templateFiles) {
    const relativePath = path.relative(templateRoot, sourceAbsolute);
    const targetFile = path.join(targetAbsolute, relativePath);

    if (dryRun) {
      console.log(`[create-start-app] would write ${path.relative(projectRoot, targetFile)}`);
      continue;
    }

    await fs.mkdir(path.dirname(targetFile), { recursive: true });
    const content = await fs.readFile(sourceAbsolute);
    await fs.writeFile(targetFile, content);
  }

  return templateFiles.length;
};

const writeStarterMetadata = async (targetAbsolute, options) => {
  const metadataPath = path.join(targetAbsolute, "purs-solid.start.json");
  const metadata = {
    appName: options.name,
    basePath: options.basePath,
    assetPrefix: options.assetPrefix,
    templateSource: "examples/solid-start",
    generatedAt: new Date().toISOString(),
  };

  await fs.writeFile(metadataPath, `${JSON.stringify(metadata, null, 2)}\n`, "utf8");
  return metadataPath;
};

const runInstall = (targetAbsolute, packageManager) => {
  if (packageManager === "none") {
    console.log("[create-start-app] skipping install (--package-manager none)");
    return;
  }

  const installArgs = packageManager === "bun" ? ["install"] : ["install"];
  const result = spawnSync(packageManager, installArgs, {
    cwd: targetAbsolute,
    stdio: "inherit",
  });

  if (result.status !== 0) {
    throw new Error(`Dependency installation failed with ${packageManager}`);
  }
};

const main = async () => {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    printUsage();
    return;
  }

  assertValidPrefix("--base-path", options.basePath);
  assertValidPrefix("--asset-prefix", options.assetPrefix);
  assertValidPackageManager(options.packageManager);

  const targetAbsolute = path.isAbsolute(options.target)
    ? options.target
    : path.join(projectRoot, options.target);

  const derivedName = path.basename(path.resolve(targetAbsolute));
  const appName = options.name ?? derivedName;
  const resolvedOptions = { ...options, name: appName };

  await ensureTemplateExists();
  await assertTargetIsWritable(targetAbsolute, options.force);

  if (!options.dryRun) {
    await fs.mkdir(targetAbsolute, { recursive: true });
  }

  const copiedCount = await copyTemplate(targetAbsolute, options.dryRun);

  let metadataPath = null;
  if (options.dryRun) {
    console.log(`[create-start-app] would write ${path.relative(projectRoot, path.join(targetAbsolute, "purs-solid.start.json"))}`);
  } else {
    metadataPath = await writeStarterMetadata(targetAbsolute, resolvedOptions);
  }

  if (!options.dryRun && options.install) {
    runInstall(targetAbsolute, options.packageManager);
  }

  const mode = options.dryRun ? "dry-run" : "copy";
  const relativeTarget = path.relative(projectRoot, targetAbsolute);
  console.log(
    `[create-start-app] ${mode} complete: ${copiedCount} file(s) from ${path.relative(projectRoot, templateRoot)} to ${relativeTarget}`
  );

  if (!options.dryRun && metadataPath != null) {
    console.log(`[create-start-app] wrote metadata: ${path.relative(projectRoot, metadataPath)}`);
  }
};

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[create-start-app] failed: ${message}`);
  console.error("[create-start-app] run with --help for usage");
  process.exitCode = 1;
});
