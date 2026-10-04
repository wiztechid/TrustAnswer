import fs from "node:fs";

const dir = "supabase/migrations";
const files = fs.readdirSync(dir).filter((f) => f.endsWith(".sql")).sort();
const pattern = /^(\d{14})_[a-z0-9_]+\.sql$/;
const seen = new Set<string>();

for (const file of files) {
  const match = file.match(pattern);
  if (!match) throw new Error(`INVALID_MIGRATION_NAME: ${file}`);
  const version = match[1];
  if (seen.has(version)) throw new Error(`DUPLICATE_MIGRATION_VERSION: ${version}`);
  seen.add(version);
}

console.log(`migration-order guard passed: ${files.length} unique migrations`);
