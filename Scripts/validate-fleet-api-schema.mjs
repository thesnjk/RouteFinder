#!/usr/bin/env node
/**
 * Pure-Node contract check: Docs/fixtures/fleet/*.json vs Docs/fleet-api-schema.json
 * definitions (required keys + basic types). No npm dependencies.
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const schemaPath = join(root, "Docs", "fleet-api-schema.json");
const fixturesDir = join(root, "Docs", "fixtures", "fleet");

const schema = JSON.parse(readFileSync(schemaPath, "utf8"));
const definitions = schema.definitions ?? {};

/** @param {unknown} value @param {string|string[]} typeSpec */
function matchesType(value, typeSpec) {
  const types = Array.isArray(typeSpec) ? typeSpec : [typeSpec];
  for (const t of types) {
    if (t === "null" && value === null) return true;
    if (t === "array" && Array.isArray(value)) return true;
    if (t === "integer" && typeof value === "number" && Number.isInteger(value)) return true;
    if (t === "number" && typeof value === "number" && !Number.isNaN(value)) return true;
    if (t === "string" && typeof value === "string") return true;
    if (t === "boolean" && typeof value === "boolean") return true;
    if (t === "object" && value !== null && typeof value === "object" && !Array.isArray(value)) {
      return true;
    }
  }
  return false;
}

/**
 * @param {unknown} value
 * @param {object} def
 * @param {string} path
 * @param {string[]} errors
 */
function validateAgainstDefinition(value, def, path, errors) {
  if (def.oneOf) {
    const ok = def.oneOf.some((branch) => {
      const branchErrors = [];
      if (branch.$ref) {
        const name = branch.$ref.split("/").pop();
        validateAgainstDefinition(value, definitions[name], path, branchErrors);
      } else if (branch.type) {
        if (!matchesType(value, branch.type)) {
          branchErrors.push(`${path}: expected type ${JSON.stringify(branch.type)}`);
        }
      }
      return branchErrors.length === 0;
    });
    if (!ok) errors.push(`${path}: failed oneOf`);
    return;
  }

  if (def.$ref) {
    const name = def.$ref.split("/").pop();
    validateAgainstDefinition(value, definitions[name], path, errors);
    return;
  }

  if (def.type && !matchesType(value, def.type)) {
    errors.push(`${path}: expected type ${JSON.stringify(def.type)}, got ${describe(value)}`);
    return;
  }

  if (def.enum && !def.enum.includes(value)) {
    errors.push(`${path}: expected one of ${JSON.stringify(def.enum)}, got ${JSON.stringify(value)}`);
  }

  if (def.type === "object" || (!def.type && def.properties)) {
    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      errors.push(`${path}: expected object`);
      return;
    }
    for (const key of def.required ?? []) {
      if (!(key in value) || value[key] === undefined) {
        errors.push(`${path}: missing required "${key}"`);
      }
    }
    for (const [key, propDef] of Object.entries(def.properties ?? {})) {
      if (value[key] === undefined) continue;
      validateAgainstDefinition(value[key], propDef, `${path}.${key}`, errors);
    }
  }

  if (def.type === "array" || def.items) {
    if (!Array.isArray(value)) {
      errors.push(`${path}: expected array`);
      return;
    }
    if (typeof def.minItems === "number" && value.length < def.minItems) {
      errors.push(`${path}: expected minItems ${def.minItems}, got ${value.length}`);
    }
    if (def.items) {
      value.forEach((item, i) => validateAgainstDefinition(item, def.items, `${path}[${i}]`, errors));
    }
  }

  if (def.type === "integer" && typeof def.minimum === "number" && value < def.minimum) {
    errors.push(`${path}: expected >= ${def.minimum}`);
  }
}

function describe(value) {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  return typeof value;
}

/** @type {{ file: string, definition: string }[]} */
const checks = [
  { file: "proxy-status.min.json", definition: "FleetProxyDeskStatus" },
  { file: "trip-snapshot.inspection.json", definition: "FleetTrip" },
];

let failed = false;
for (const { file, definition } of checks) {
  const def = definitions[definition];
  if (!def) {
    console.error(`Missing schema definition: ${definition}`);
    failed = true;
    continue;
  }
  const fixturePath = join(fixturesDir, file);
  const fixture = JSON.parse(readFileSync(fixturePath, "utf8"));
  const errors = [];
  validateAgainstDefinition(fixture, def, definition, errors);
  if (errors.length) {
    failed = true;
    console.error(`FAIL ${file} vs ${definition}:`);
    for (const err of errors) console.error(`  - ${err}`);
  } else {
    console.log(`OK   ${file} ↔ ${definition}`);
  }
}

if (failed) {
  process.exit(1);
}
console.log("Fleet API schema contract: all fixtures valid.");
