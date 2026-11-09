import { describe, expect, it } from "vitest";
import type { AuthSession } from "../src/features/shared/contract";
import { sha256Hex } from "../src/lib/crypto";
import { json, newUser } from "./accounts";
import { appleToken } from "./apple";
import { call, env } from "./helpers";
import { lastCodeFor, outbox } from "./mail";

// Every column that names a user; the test below also checks this list covers every foreign key to users.
const USER_COLUMNS: [string, string][] = [
  ["users", "id"],
  ["auth_identities", "user_id"],
  ["sessions", "user_id"],
  ["devices", "user_id"],
  ["app_refs", "user_id"],
  ["blocks_meta", "user_id"],
  ["events", "user_id"],
  ["rollups_daily", "user_id"],
  ["rollups_weekly", "user_id"],
  ["hour_histograms", "user_id"],
  ["exam_weeks", "user_id"],
  ["friendships", "user_lo"],
  ["friendships", "user_hi"],
  ["invites", "user_id"],
  ["person_blocks", "blocker_id"],
  ["person_blocks", "blocked_id"],
  ["contact_hashes", "user_id"],
  ["school_memberships", "user_id"],
  ["idempotency_keys", "user_id"],
];

async function seedEverything(userId: string, otherId: string) {
  const now = Date.now();
  const [lo, hi] = [userId, otherId].sort();
  const statements = [
    ["INSERT INTO app_refs VALUES (?, 'a1', 'instagram', ?)", userId, now],
    ["INSERT INTO blocks_meta VALUES (?, 'b1', '{}', '[]', ?)", userId, now],
    [
      "INSERT INTO events (event_id, user_id, device_id, type, occurred_at, tz_offset, received_at) VALUES (?, ?, 'd', 'checkin', ?, 0, ?)",
      crypto.randomUUID(),
      userId,
      now,
      now,
    ],
    ["INSERT INTO rollups_daily (user_id, day) VALUES (?, '2026-11-09')", userId],
    ["INSERT INTO rollups_weekly (user_id, week) VALUES (?, '2026-11-09')", userId],
    ["INSERT INTO hour_histograms VALUES (?, '2026-11-09', '[]')", userId],
    ["INSERT INTO exam_weeks VALUES (?, '2026-11-09')", userId],
    ["INSERT INTO friendships VALUES (?, ?, 'accepted', ?, ?, ?)", lo, hi, userId, now, now],
    ["INSERT INTO person_blocks VALUES (?, ?, ?)", otherId, userId, now],
    ["INSERT INTO person_blocks VALUES (?, ?, ?)", userId, otherId, now],
    ["INSERT INTO contact_hashes VALUES (?, 'h')", userId],
    ["INSERT INTO school_memberships VALUES (?, 1923058245, 'e', ?)", userId, now],
    ["INSERT INTO devices (id, user_id, updated_at) VALUES (?, ?, ?)", crypto.randomUUID(), userId, now],
    ["INSERT INTO idempotency_keys VALUES (?, 'k', 200, '', ?)", userId, now],
  ] as const;
  await env.DB.batch(statements.map(([sql, ...args]) => env.DB.prepare(sql).bind(...args)));
}

async function rowsFor(userId: string) {
  const counts: Record<string, number> = {};
  for (const [table, column] of USER_COLUMNS) {
    const row = await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE ${column} = ?`)
      .bind(userId)
      .first<{ n: number }>();
    counts[`${table}.${column}`] = row?.n ?? 0;
  }
  return counts;
}

describe("account deletion (E3.20)", () => {
  it("covers every foreign key to users", async () => {
    const tables = await env.DB.prepare(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' AND name != 'd1_migrations'",
    ).all<{ name: string }>();
    for (const { name } of tables.results) {
      const fks = await env.DB.prepare(`PRAGMA foreign_key_list(${name})`).all<{
        table: string;
        from: string;
      }>();
      for (const fk of fks.results.filter((f) => f.table === "users")) {
        expect(USER_COLUMNS).toContainEqual([name, fk.from]);
      }
    }
  });

  it("re-authenticates by email code and leaves no rows for the user", async () => {
    const user = await newUser();
    const other = await newUser();
    await seedEverything(user.id, other.id);
    const before = await rowsFor(user.id);
    const empty = Object.entries(before).filter(([key, n]) => n === 0 && !key.startsWith("friendships"));
    expect(empty).toEqual([]);

    const wrong = await call("/v1/account", {
      method: "DELETE",
      token: user.token,
      json: { reauth: { kind: "email", code: "000000" } },
    });
    expect(wrong.status).toBe(410);

    await env.DB.prepare("UPDATE email_codes SET sent_at = 0").run();
    await call("/v1/auth/email/start", { method: "POST", json: { email: user.email } });
    const res = await call("/v1/account", {
      method: "DELETE",
      token: user.token,
      json: { reauth: { kind: "email", code: lastCodeFor(user.email) } },
    });
    expect(res.status).toBe(204);
    expect(Object.values(await rowsFor(user.id)).every((n) => n === 0)).toBe(true);
    expect(outbox.at(-1)?.to).toBe(user.email);
    expect(outbox.at(-1)?.subject).toBe("Your Toll account was deleted");
    expect((await call("/v1/me", { token: other.token })).status).toBe(200);
    expect((await call("/v1/me", { token: user.token })).status).toBe(401);
  });

  it("re-authenticates with Apple, tombstones the subject, and allows a fresh account", async () => {
    const sub = crypto.randomUUID();
    const signIn = async () => {
      const { token, nonce } = await appleToken({ sub });
      return json<AuthSession>(
        call("/v1/auth/apple", {
          method: "POST",
          json: { identityToken: token, authorizationCode: "c", nonce, deviceId: "d" },
        }),
      );
    };
    const session = await signIn();
    const someoneElse = await appleToken();
    const refused = await call("/v1/account", {
      method: "DELETE",
      token: session.token,
      json: {
        reauth: {
          kind: "apple",
          authorizationCode: "c",
          identityToken: someoneElse.token,
          nonce: someoneElse.nonce,
        },
      },
    });
    expect(refused.status).toBe(403);

    const { token, nonce } = await appleToken({ sub });
    const res = await call("/v1/account", {
      method: "DELETE",
      token: session.token,
      json: { reauth: { kind: "apple", authorizationCode: "c", identityToken: token, nonce } },
    });
    expect(res.status).toBe(204);
    const tombstone = await env.DB.prepare("SELECT * FROM tombstones WHERE subject_hash = ?")
      .bind(await sha256Hex(`apple:${sub}`))
      .first();
    expect(tombstone).not.toBeNull();

    const fresh = await signIn();
    expect(fresh.isNew).toBe(true);
    expect(fresh.user.id).not.toBe(session.user.id);
  });
});
