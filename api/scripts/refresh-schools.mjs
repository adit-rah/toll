// Rebuilds seed/schools.sql from the Hipo university domains list, filtered to CA/US/GB (spec §11.2).
// Apply with: npx wrangler d1 execute toll --remote --file seed/schools.sql
import { writeFileSync } from "node:fs";

const SOURCE =
  "https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json";
const COUNTRIES = new Set(["CA", "US", "GB"]);

// Ids must stay stable across refreshes because school_memberships points at them.
function stableId(country, name) {
  let h = 0x811c9dc5;
  for (const ch of `${country}:${name.toLowerCase()}`) {
    h ^= ch.codePointAt(0);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h & 0x7fffffff;
}

const sql = (s) => `'${s.replaceAll("'", "''")}'`;

const res = await fetch(SOURCE);
if (!res.ok) throw new Error(`fetch failed: ${res.status}`);
const rows = (await res.json()).filter((u) => COUNTRIES.has(u.alpha_two_code));

const schools = new Map();
const domains = new Map();
for (const u of rows) {
  const id = stableId(u.alpha_two_code, u.name);
  const existing = schools.get(id);
  if (existing && existing.name.toLowerCase() !== u.name.toLowerCase()) throw new Error(`id collision: ${existing.name} / ${u.name}`);
  schools.set(id, { name: u.name, country: u.alpha_two_code });
  for (const raw of u.domains ?? []) {
    const domain = raw.trim().toLowerCase();
    if (domain && !domains.has(domain)) domains.set(domain, id);
  }
}

const lines = ["DELETE FROM school_domains;"];
for (const [id, s] of [...schools].sort((a, b) => a[0] - b[0])) {
  lines.push(
    `INSERT INTO schools (id, name, country) VALUES (${id}, ${sql(s.name)}, ${sql(s.country)}) ON CONFLICT(id) DO UPDATE SET name = excluded.name, country = excluded.country;`,
  );
}
for (const [domain, id] of [...domains].sort()) {
  lines.push(`INSERT INTO school_domains (domain, school_id) VALUES (${sql(domain)}, ${id});`);
}

writeFileSync(new URL("../seed/schools.sql", import.meta.url), `${lines.join("\n")}\n`);
console.log(`${schools.size} schools, ${domains.size} domains`);
