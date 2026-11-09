import { describe, expect, it } from "vitest";
import { exportTables, nightly } from "../src/features/jobs/maintenance";
import { database } from "../src/lib/db";
import { newUser } from "./accounts";
import { DAY, ev, HOUR, upload } from "./events";
import { env } from "./helpers";

const count = async (sql: string, ...args: unknown[]) =>
  (
    await env.DB.prepare(sql)
      .bind(...args)
      .first<{ n: number }>()
  )?.n ?? 0;

describe("nightly and weekly jobs (E11.49)", () => {
  it("prunes old raw events, spent codes, expired sessions and stale idempotency keys, keeping rollups", async () => {
    const user = await newUser();
    const now = Date.now();
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO events (event_id, user_id, device_id, type, occurred_at, tz_offset, received_at) VALUES (?, ?, 'd', 'pass', ?, 0, ?)",
      ).bind(crypto.randomUUID(), user.id, now - 91 * DAY, now - 91 * DAY),
      env.DB.prepare("INSERT INTO rollups_daily (user_id, day, passes) VALUES (?, '2026-01-05', 3)").bind(
        user.id,
      ),
      env.DB.prepare("INSERT INTO email_codes VALUES ('prune:old', 'h', ?, 0, NULL, ?, NULL)").bind(
        now - DAY,
        now - DAY,
      ),
      env.DB.prepare("INSERT INTO email_codes VALUES ('prune:locked', 'h', ?, 5, ?, ?, NULL)").bind(
        now - DAY,
        now + HOUR,
        now - DAY,
      ),
      env.DB.prepare("INSERT INTO sessions VALUES ('prune-old', ?, NULL, 0, ?)").bind(user.id, now - 1),
      env.DB.prepare("INSERT INTO idempotency_keys VALUES (?, 'old', 200, '', ?)").bind(
        user.id,
        now - 25 * HOUR,
      ),
      env.DB.prepare("INSERT INTO idempotency_keys VALUES (?, 'new', 200, '', ?)").bind(user.id, now),
    ]);
    await upload(user, [ev("checkin", now - HOUR)]);

    const result = await nightly(database(env.DB), now);
    expect(result.pruned.events).toBeGreaterThanOrEqual(1);
    expect(await count("SELECT COUNT(*) AS n FROM events WHERE user_id = ?", user.id)).toBe(1);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM rollups_daily WHERE user_id = ? AND day = '2026-01-05'",
        user.id,
      ),
    ).toBe(1);
    expect(await count("SELECT COUNT(*) AS n FROM email_codes WHERE key LIKE 'prune:%'")).toBe(1);
    expect(await count("SELECT COUNT(*) AS n FROM sessions WHERE token_hash = 'prune-old'")).toBe(0);
    expect(await count("SELECT COUNT(*) AS n FROM idempotency_keys WHERE user_id = ?", user.id)).toBe(1);
    expect(result.rollups.users).toBeGreaterThanOrEqual(1);
  });

  it("exports every table as NDJSON to R2", async () => {
    const user = await newUser();
    const now = Date.UTC(2026, 10, 9, 11);
    const keys = await exportTables(database(env.DB), env, now);
    expect(keys).toContain("exports/2026-11-09/users.ndjson");
    expect(keys).toContain("exports/2026-11-09/events.ndjson");
    const users = await (await env.STORAGE.get("exports/2026-11-09/users.ndjson"))?.text();
    const rows = (users ?? "")
      .trim()
      .split("\n")
      .map((line) => JSON.parse(line) as { id: string });
    expect(rows.some((row) => row.id === user.id)).toBe(true);
  });
});
