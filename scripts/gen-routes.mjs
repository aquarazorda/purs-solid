import { promises as fs } from "node:fs";
import path from "node:path";
import process from "node:process";

const projectRoot = process.cwd();
const defaultRoutesRoot = path.join(projectRoot, "src", "Examples", "SolidStart", "Routes");
const defaultOutputFile = path.join(projectRoot, "src", "Solid", "Start", "Internal", "Manifest.purs");

const options = parseCliOptions(process.argv.slice(2));
const routesRoot = toAbsolutePath(options.routesRoot ?? defaultRoutesRoot);
const outputFile = toAbsolutePath(options.outputFile ?? defaultOutputFile);

const modulePattern = /^\s*module\s+([A-Za-z0-9_'.]+)\s+where/m;

const isParamSegment = (segment) => /^\[[A-Za-z0-9_]+\]$/.test(segment);
const isCatchAllSegment = (segment) => /^\[\.\.\.[A-Za-z0-9_]+\]$/.test(segment);
const isOptionalSegment = (segment) => /^\[\[[A-Za-z0-9_]+\]\]$/.test(segment);

const psString = (value) => JSON.stringify(value);

function parseCliOptions(argv) {
  const result = {};

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--routes-root") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Missing value for --routes-root");
      }
      result.routesRoot = value;
      index += 1;
      continue;
    }

    if (token === "--output") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Missing value for --output");
      }
      result.outputFile = value;
      index += 1;
      continue;
    }

    throw new Error(`Unknown option: ${token}`);
  }

  return result;
}

function toAbsolutePath(value) {
  if (path.isAbsolute(value)) {
    return value;
  }

  return path.join(projectRoot, value);
}

async function pathExistsAsDirectory(target) {
  try {
    const stat = await fs.stat(target);
    return stat.isDirectory();
  } catch {
    return false;
  }
}

async function walkPursFiles(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const nested = await walkPursFiles(fullPath);
      files.push(...nested);
    } else if (entry.isFile() && entry.name.endsWith(".purs")) {
      files.push(fullPath);
    }
  }

  return files;
}

function toPosixPath(filePath) {
  return filePath.split(path.sep).join("/");
}

function stripPursExtension(relativePath) {
  return relativePath.replace(/\.purs$/, "");
}

function parseModuleName(fileContent, filePath) {
  const match = fileContent.match(modulePattern);
  if (!match) {
    throw new Error(`Missing module declaration in ${filePath}`);
  }
  return match[1];
}

function toRouteSegments(relativeNoExtension) {
  const rawSegments = relativeNoExtension.split("/").filter(Boolean);
  if (rawSegments.length === 0) {
    return [];
  }

  if (rawSegments[rawSegments.length - 1] === "index") {
    rawSegments.pop();
  }

  return rawSegments;
}

function segmentToPatternExpression(segment) {
  if (isCatchAllSegment(segment)) {
    const name = segment.slice(4, -1);
    return `CatchAll ${psString(name)}`;
  }

  if (isOptionalSegment(segment)) {
    const name = segment.slice(2, -2);
    return `Optional ${psString(name)}`;
  }

  if (isParamSegment(segment)) {
    const name = segment.slice(1, -1);
    return `Param ${psString(name)}`;
  }

  return `Static ${psString(segment)}`;
}

function segmentToRouteIdPart(segment) {
  if (isCatchAllSegment(segment)) {
    const name = segment.slice(4, -1);
    return `*${name}`;
  }

  if (isOptionalSegment(segment)) {
    const name = segment.slice(2, -2);
    return `:${name}?`;
  }

  if (isParamSegment(segment)) {
    const name = segment.slice(1, -1);
    return `:${name}`;
  }

  return segment;
}

function routeIdFromSegments(segments) {
  if (segments.length === 0) {
    return "/";
  }

  return `/${segments.map(segmentToRouteIdPart).join("/")}`;
}

function segmentKind(segment) {
  if (isCatchAllSegment(segment)) {
    return { kind: "catchAll", value: segment.slice(4, -1) };
  }

  if (isOptionalSegment(segment)) {
    return { kind: "optional", value: segment.slice(2, -2) };
  }

  if (isParamSegment(segment)) {
    return { kind: "param", value: segment.slice(1, -1) };
  }

  return { kind: "static", value: segment };
}

function signaturePart(segment) {
  const parsed = segmentKind(segment);
  if (parsed.kind === "static") {
    return `static:${parsed.value}`;
  }

  return parsed.kind;
}

function signatureKey(segments) {
  return segments.map(signaturePart).join("/");
}

function hasDynamicSegments(segments) {
  return segments.some((segment) => {
    const parsed = segmentKind(segment);
    return parsed.kind !== "static";
  });
}

function hasOptionalOrCatchAll(segments) {
  return segments.some((segment) => {
    const parsed = segmentKind(segment);
    return parsed.kind === "optional" || parsed.kind === "catchAll";
  });
}

function detectEquivalentShapeConflicts(entries) {
  const bySignature = new Map();

  for (const entry of entries) {
    const key = signatureKey(entry.patternSegments);
    const current = bySignature.get(key) ?? [];
    current.push(entry);
    bySignature.set(key, current);
  }

  const warnings = [];
  for (const [key, group] of bySignature.entries()) {
    if (group.length <= 1) {
      continue;
    }

    if (!group.some((entry) => hasDynamicSegments(entry.patternSegments))) {
      continue;
    }

    const sourceList = group.map((entry) => entry.sourcePath).join(", ");
    warnings.push(
      `Equivalent dynamic route shape (${key}) appears in multiple files: ${sourceList}. ` +
        "Consider using one canonical route to avoid ambiguous param naming."
    );
  }

  return warnings;
}

function canMatchEmpty(segments, index) {
  for (let i = index; i < segments.length; i += 1) {
    const parsed = segmentKind(segments[i]);
    if (parsed.kind === "optional") {
      continue;
    }

    if (parsed.kind === "catchAll" && i === segments.length - 1) {
      continue;
    }

    return false;
  }

  return true;
}

function overlapStateKey(leftIndex, rightIndex) {
  return `${leftIndex}:${rightIndex}`;
}

function segmentsCanOverlap(leftSegments, rightSegments) {
  const memo = new Map();

  const go = (leftIndex, rightIndex) => {
    const key = overlapStateKey(leftIndex, rightIndex);
    if (memo.has(key)) {
      return memo.get(key);
    }

    let result = false;

    if (leftIndex === leftSegments.length && rightIndex === rightSegments.length) {
      result = true;
    } else if (leftIndex === leftSegments.length) {
      result = canMatchEmpty(rightSegments, rightIndex);
    } else if (rightIndex === rightSegments.length) {
      result = canMatchEmpty(leftSegments, leftIndex);
    } else {
      const left = segmentKind(leftSegments[leftIndex]);
      const right = segmentKind(rightSegments[rightIndex]);

      if (left.kind === "optional") {
        result = go(leftIndex + 1, rightIndex) || go(leftIndex + 1, rightIndex + 1);
      } else if (right.kind === "optional") {
        result = go(leftIndex, rightIndex + 1) || go(leftIndex + 1, rightIndex + 1);
      } else if (left.kind === "catchAll") {
        if (leftIndex === leftSegments.length - 1) {
          result = true;
        } else {
          result = go(leftIndex + 1, rightIndex) || go(leftIndex, rightIndex + 1);
        }
      } else if (right.kind === "catchAll") {
        if (rightIndex === rightSegments.length - 1) {
          result = true;
        } else {
          result = go(leftIndex, rightIndex + 1) || go(leftIndex + 1, rightIndex);
        }
      } else if (left.kind === "static" && right.kind === "static") {
        result = left.value === right.value && go(leftIndex + 1, rightIndex + 1);
      } else {
        result = go(leftIndex + 1, rightIndex + 1);
      }
    }

    memo.set(key, result);
    return result;
  };

  return go(0, 0);
}

function detectOptionalCatchAllOverlaps(entries) {
  const warnings = [];
  const seenPairs = new Set();

  for (let leftIndex = 0; leftIndex < entries.length; leftIndex += 1) {
    for (let rightIndex = leftIndex + 1; rightIndex < entries.length; rightIndex += 1) {
      const left = entries[leftIndex];
      const right = entries[rightIndex];

      if (!hasOptionalOrCatchAll(left.patternSegments) && !hasOptionalOrCatchAll(right.patternSegments)) {
        continue;
      }

      if (!segmentsCanOverlap(left.patternSegments, right.patternSegments)) {
        continue;
      }

      const pairKey = [left.sourcePath, right.sourcePath].sort().join("::");
      if (seenPairs.has(pairKey)) {
        continue;
      }

      seenPairs.add(pairKey);
      warnings.push(
        `Potential optional/catch-all overlap between ${left.sourcePath} (${left.id}) and ${right.sourcePath} (${right.id}). ` +
          "Use a more specific static prefix or remove optional/catch-all overlap if this is unintended."
      );
    }
  }

  return warnings;
}

function detectRouteDiagnostics(entries) {
  return [
    ...detectEquivalentShapeConflicts(entries),
    ...detectOptionalCatchAllOverlaps(entries)
  ];
}

function renderManifest(entries, generatedFromRoot) {
  const imports = ["import Solid.Start.Routing (RouteDef)"];
  if (entries.length > 0) {
    imports.unshift("import Solid.Start.Route.Pattern (RoutePattern(..), Segment(..))");
  }

  const header = [
    "module Solid.Start.Internal.Manifest",
    "  ( allRoutes",
    "  ) where",
    "",
    ...imports,
    "",
    "-- This file is generated by scripts/gen-routes.mjs.",
    "-- Generated from route root: " + psString(generatedFromRoot),
    "-- Do not edit manually.",
    "",
    "allRoutes :: Array RouteDef"
  ];

  if (entries.length === 0) {
    return `${header.join("\n")}\nallRoutes = []\n`;
  }

  const renderedEntries = entries
    .map((entry) => {
      const patternExpr = entry.patternSegments.map(segmentToPatternExpression).join(", ");
      return [
        "  { id: " + psString(entry.id),
        "  , pattern: RoutePattern [" + patternExpr + "]",
        "  , moduleName: " + psString(entry.moduleName),
        "  , sourcePath: " + psString(entry.sourcePath),
        "  }"
      ].join("\n");
    })
    .join("\n  , ");

  return `${header.join("\n")}\nallRoutes =\n  [ ${renderedEntries}\n  ]\n`;
}

async function main() {
  const hasRoutesDirectory = await pathExistsAsDirectory(routesRoot);
  const routeFiles = hasRoutesDirectory ? await walkPursFiles(routesRoot) : [];

  const entries = [];
  for (const absoluteFilePath of routeFiles) {
    const content = await fs.readFile(absoluteFilePath, "utf8");
    const moduleName = parseModuleName(content, absoluteFilePath);
    const relativePath = toPosixPath(path.relative(routesRoot, absoluteFilePath));
    const relativeNoExtension = stripPursExtension(relativePath);
    const patternSegments = toRouteSegments(relativeNoExtension);
    const id = routeIdFromSegments(patternSegments);

    entries.push({
      id,
      moduleName,
      sourcePath: relativePath,
      patternSegments
    });
  }

  entries.sort((left, right) => {
    if (left.id === right.id) {
      return left.sourcePath.localeCompare(right.sourcePath);
    }
    return left.id.localeCompare(right.id);
  });

  const seenById = new Map();
  for (const entry of entries) {
    const existing = seenById.get(entry.id);
    if (existing) {
      throw new Error(
        `Duplicate route id ${entry.id} from ${existing.sourcePath} and ${entry.sourcePath}`
      );
    }
    seenById.set(entry.id, entry);
  }

  const warnings = detectRouteDiagnostics(entries);
  for (const warning of warnings) {
    console.warn(`[gen-routes][warning] ${warning}`);
  }

  const output = renderManifest(entries, toPosixPath(path.relative(projectRoot, routesRoot)));
  await fs.mkdir(path.dirname(outputFile), { recursive: true });
  await fs.writeFile(outputFile, output, "utf8");

  const mode = hasRoutesDirectory ? "scan" : "empty";
  console.log(
    `[gen-routes] ${mode} mode: scanned ${path.relative(projectRoot, routesRoot)} and wrote ${entries.length} route(s) to ${path.relative(projectRoot, outputFile)}`
  );

  if (warnings.length > 0) {
    console.log(`[gen-routes] produced ${warnings.length} route warning(s)`);
  }
}

main().catch((error) => {
  console.error("[gen-routes] failed:", error);
  process.exitCode = 1;
});
