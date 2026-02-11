import { promises as fs } from "node:fs";
import path from "node:path";
import process from "node:process";

const projectRoot = process.cwd();
const templateRoot = path.join(projectRoot, "examples", "solid-start");

function parseArgs(argv) {
  const positional = [];
  let dryRun = false;

  for (const token of argv) {
    if (token === "--dry-run") {
      dryRun = true;
      continue;
    }

    positional.push(token);
  }

  if (positional.length !== 1) {
    throw new Error("Usage: node scripts/create-solid-start-app.mjs [--dry-run] <target-directory>");
  }

  return {
    dryRun,
    target: positional[0],
  };
}

async function walkFiles(dir) {
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
}

async function assertTemplateExists() {
  try {
    const stat = await fs.stat(templateRoot);
    if (!stat.isDirectory()) {
      throw new Error("Template root is not a directory");
    }
  } catch {
    throw new Error(`Template root not found: ${path.relative(projectRoot, templateRoot)}`);
  }
}

async function assertTargetIsWritable(targetAbsolute) {
  try {
    const stat = await fs.stat(targetAbsolute);
    if (!stat.isDirectory()) {
      throw new Error("Target path exists and is not a directory");
    }

    const entries = await fs.readdir(targetAbsolute);
    if (entries.length > 0) {
      throw new Error("Target directory already exists and is not empty");
    }
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return;
    }

    throw error;
  }
}

async function copyTemplate(targetAbsolute, dryRun) {
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
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const targetAbsolute = path.isAbsolute(options.target)
    ? options.target
    : path.join(projectRoot, options.target);

  await assertTemplateExists();
  await assertTargetIsWritable(targetAbsolute);

  if (!options.dryRun) {
    await fs.mkdir(targetAbsolute, { recursive: true });
  }

  const copiedCount = await copyTemplate(targetAbsolute, options.dryRun);
  const mode = options.dryRun ? "dry-run" : "copy";
  console.log(
    `[create-start-app] ${mode} complete: ${copiedCount} file(s) from ${path.relative(projectRoot, templateRoot)} to ${path.relative(projectRoot, targetAbsolute)}`
  );
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[create-start-app] failed: ${message}`);
  process.exitCode = 1;
});
