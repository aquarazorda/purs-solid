import { readFile } from "node:fs/promises";
import { access } from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import { join } from "node:path";
import { cwd, exit } from "node:process";

const rootDir = cwd();
const matrixPath = join(rootDir, "API_COVERAGE_MATRIX.json");

const exists = async (path) => {
  try {
    await access(path, fsConstants.F_OK);
    return true;
  } catch {
    return false;
  }
};

const readText = async (path) => readFile(path, "utf8");

const main = async () => {
  const raw = await readText(matrixPath);
  const matrix = JSON.parse(raw);

  if (!Array.isArray(matrix.entries)) {
    throw new Error("Coverage matrix must contain an entries array");
  }

  const failures = [];

  for (const entry of matrix.entries) {
    const modulePath = join(rootDir, entry.module);
    const moduleExists = await exists(modulePath);
    if (!moduleExists) {
      failures.push(`[${entry.id}] missing module file: ${entry.module}`);
      continue;
    }

    const moduleContent = await readText(modulePath);

    for (const symbol of entry.symbols ?? []) {
      const symbolPattern = new RegExp(`\\b${symbol}\\b`);
      if (!symbolPattern.test(moduleContent)) {
        failures.push(`[${entry.id}] missing symbol in module: ${symbol}`);
      }
    }

    for (const testPath of entry.tests ?? []) {
      const absoluteTestPath = join(rootDir, testPath);
      const testExists = await exists(absoluteTestPath);
      if (!testExists) {
        failures.push(`[${entry.id}] missing coverage file: ${testPath}`);
        continue;
      }

      const testContent = await readText(absoluteTestPath);
      let hasCoveredSymbol = false;
      for (const symbol of entry.symbols ?? []) {
        const symbolPattern = new RegExp(`\\b${symbol}\\b`);
        if (symbolPattern.test(testContent)) {
          hasCoveredSymbol = true;
          break;
        }
      }

      if (!hasCoveredSymbol && (entry.symbols ?? []).length > 0) {
        failures.push(`[${entry.id}] coverage file missing symbol references: ${testPath}`);
      }
    }
  }

  if (failures.length > 0) {
    console.error("[coverage-matrix] failed checks:");
    for (const failure of failures) {
      console.error(`- ${failure}`);
    }
    exit(1);
  }

  console.log(`[coverage-matrix] verified ${matrix.entries.length} entries`);
};

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[coverage-matrix] ${message}`);
  exit(1);
});
