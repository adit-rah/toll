import { env } from "./helpers";

export const WATERLOO = { id: 1923058245, name: "University of Waterloo" };
export const USJC = { id: 1076875004, name: "University of St. Jerome's College" };

await env.DB.batch([
  env.DB.prepare("INSERT OR IGNORE INTO schools VALUES (?, ?, 'CA')").bind(WATERLOO.id, WATERLOO.name),
  env.DB.prepare("INSERT OR IGNORE INTO schools VALUES (?, ?, 'CA')").bind(USJC.id, USJC.name),
  env.DB.prepare("INSERT OR IGNORE INTO school_domains VALUES ('uwaterloo.ca', ?)").bind(WATERLOO.id),
  env.DB.prepare("INSERT OR IGNORE INTO school_domains VALUES ('usjc.uwaterloo.ca', ?)").bind(USJC.id),
]);

// A school of its own per test, so aggregates are not shared with other tests.
export async function newSchool(): Promise<{ id: number; name: string; domain: string }> {
  const id = Math.floor(Math.random() * 1_000_000_000) + 2_000_000_000;
  const domain = `s${id}.edu`;
  const name = `Test School ${id}`;
  await env.DB.batch([
    env.DB.prepare("INSERT INTO schools VALUES (?, ?, 'US')").bind(id, name),
    env.DB.prepare("INSERT INTO school_domains VALUES (?, ?)").bind(domain, id),
  ]);
  return { id, name, domain };
}

export async function joinSchool(userId: string, schoolId = WATERLOO.id) {
  await env.DB.prepare(
    "INSERT INTO school_memberships VALUES (?, ?, ?, ?) ON CONFLICT (user_id) DO UPDATE SET school_id = excluded.school_id",
  )
    .bind(userId, schoolId, crypto.randomUUID(), Date.now())
    .run();
}
