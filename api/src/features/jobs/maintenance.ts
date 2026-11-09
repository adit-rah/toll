import { defaultConfig, serverConfig } from "../../config";
import { DAY_MS, HOUR_MS } from "../../domain/time";
import type { Env } from "../../env";
import type { Database } from "../../lib/db";
import { recomputeRecent } from "../rollups/recent";

const PRUNE_BATCH = 5000;

// Deletes in slices so one nightly run never holds D1's single writer for long.
async function pruneWhere(db: Database, table: string, where: string, ...args: unknown[]): Promise<number> {
  let total = 0;
  for (;;) {
    const result = await db.$client
      .prepare(
        `DELETE FROM ${table} WHERE rowid IN (SELECT rowid FROM ${table} WHERE ${where} LIMIT ${PRUNE_BATCH})`,
      )
      .bind(...args)
      .run();
    total += result.meta.changes;
    if (result.meta.changes < PRUNE_BATCH) return total;
  }
}

export async function prune(db: Database, nowMs: number) {
  return {
    events: await pruneWhere(
      db,
      "events",
      "occurred_at < ?",
      nowMs - defaultConfig.retention.rawEventDays * DAY_MS,
    ),
    emailCodes: await pruneWhere(
      db,
      "email_codes",
      "expires_at < ?1 AND (locked_until IS NULL OR locked_until < ?1)",
      nowMs,
    ),
    sessions: await pruneWhere(db, "sessions", "expires_at < ?", nowMs),
    idempotencyKeys: await pruneWhere(
      db,
      "idempotency_keys",
      "created_at < ?",
      nowMs - serverConfig.idempotencyTtlHours * HOUR_MS,
    ),
  };
}

// Spec §11.2 nightly: late events and day-boundary stragglers settle, then school aggregates, then retention.
export async function nightly(db: Database, nowMs: number) {
  const rollups = await recomputeRecent(db, nowMs, serverConfig.nightlyRecomputeDays);
  const pruned = await prune(db, nowMs);
  return { rollups, pruned };
}

// Spec §13: D1 Time Travel plus this weekly NDJSON copy in R2 are the backup.
export async function exportTables(db: Database, env: Env, nowMs: number): Promise<string[]> {
  const date = new Date(nowMs).toISOString().slice(0, 10);
  const { results } = await db.$client
    .prepare(
      `SELECT name FROM sqlite_master WHERE type = 'table'
       AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' AND name != 'd1_migrations' ORDER BY name`,
    )
    .all<{ name: string }>();
  const written: string[] = [];
  for (const { name } of results) {
    const lines: string[] = [];
    for (let offset = 0; ; offset += serverConfig.exportPageRows) {
      const page = await db.$client
        .prepare(`SELECT * FROM "${name}" ORDER BY rowid LIMIT ? OFFSET ?`)
        .bind(serverConfig.exportPageRows, offset)
        .all();
      for (const row of page.results) lines.push(JSON.stringify(row));
      if (page.results.length < serverConfig.exportPageRows) break;
    }
    const key = `exports/${date}/${name}.ndjson`;
    await env.STORAGE.put(key, lines.length ? `${lines.join("\n")}\n` : "", {
      httpMetadata: { contentType: "application/x-ndjson" },
    });
    written.push(key);
  }
  return written;
}
