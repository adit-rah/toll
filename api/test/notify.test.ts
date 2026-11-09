import { exportPKCS8, generateKeyPair } from "jose";
import { describe, expect, it } from "vitest";
import { copy, ordinal } from "../src/copy";
import { addDays, dayStartMs, offsetMinutesIn, tollTimeIn, weekOf } from "../src/domain/time";
import type { PushMessage } from "../src/env";
import { deliverPushes } from "../src/features/notify/consumer";
import { dailyPushes, dailySummary, dueUsers } from "../src/features/notify/summary";
import { database } from "../src/lib/db";
import { deps } from "../src/lib/deps";
import { newUser, type TestUser } from "./accounts";
import { ev, HOUR, upload } from "./events";
import { call, env } from "./helpers";
import { befriend } from "./social";

const ZONE = "America/Toronto";

async function device(user: TestUser, timezone: string, token = crypto.randomUUID().replace(/-/g, "")) {
  await call("/v1/devices", {
    method: "PUT",
    token: user.token,
    json: { deviceId: crypto.randomUUID(), pushToken: token, pushEnvironment: "sandbox", timezone },
  });
  return token;
}

async function passesOn(user: TestUser, day: string, count: number) {
  const start = dayStartMs(day, offsetMinutesIn(ZONE, Date.now()), 4) + 10 * HOUR;
  const tzOffset = offsetMinutesIn(ZONE, start);
  const events = Array.from({ length: count }, (_, i) =>
    ev("pass", start + i * 1000, { free: true, tzOffset }),
  );
  if (events.length) await upload(user, events, "/v1/events/history");
}

describe("daily summary sentence (N-13, spec §10)", () => {
  it("writes ordinals", () => {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 101, 111, 112].map(ordinal)).toEqual([
      "1st",
      "2nd",
      "3rd",
      "4th",
      "11th",
      "12th",
      "13th",
      "21st",
      "22nd",
      "23rd",
      "101st",
      "111th",
      "112th",
    ]);
  });

  it("matches the spec sentence, with pluralisation and requests", () => {
    expect(copy.dailySummary({ passes: 4, rank: 2, of: 6, requests: 0 })).toBe(
      "4 passes yesterday. 2nd of 6 friends.",
    );
    expect(copy.dailySummary({ passes: 4, rank: 2, of: 6, requests: 1 })).toBe(
      "4 passes yesterday. 2nd of 6 friends. 1 friend request waiting.",
    );
    expect(copy.dailySummary({ passes: 1, rank: null, of: 1, requests: 0 })).toBe("1 pass yesterday.");
    expect(copy.dailySummary({ passes: 0, rank: null, of: 1, requests: 2 })).toBe(
      "0 passes yesterday. 2 friend requests waiting.",
    );
  });

  it("ranks you among your friends by improvement for the week holding yesterday", async () => {
    const me = await newUser({ name: "Me" });
    const fast = await newUser({ name: "Fast" });
    const fresh = await newUser({ name: "Fresh" });
    await befriend(me, fast);
    await befriend(me, fresh);
    await call("/v1/friends/requests", {
      method: "POST",
      token: (await newUser()).token,
      json: { userId: me.id },
    });
    const yesterday = addDays(tollTimeIn(ZONE, Date.now(), 4).day, -1);
    const lastWeek = addDays(weekOf(yesterday), -7);
    await passesOn(me, yesterday, 4);
    await passesOn(me, lastWeek, 5);
    await passesOn(fast, yesterday, 1);
    await passesOn(fast, lastWeek, 2);
    await passesOn(fresh, yesterday, 3);

    const summary = await dailySummary(database(env.DB), me.id, Date.now());
    expect(summary.body).toBe("4 passes yesterday. 2nd of 3 friends. 1 friend request waiting.");
  });
});

describe("daily summary selection (§11.3)", () => {
  it("picks devices whose local hour is the summary hour; background for all, alert only when on", async () => {
    const now = Date.UTC(2026, 10, 9, 1, 0);
    const tokyo = await newUser();
    const toronto = await newUser();
    const evening = await newUser();
    const off = await newUser();
    const tokyoToken = await device(tokyo, "Asia/Tokyo");
    await device(toronto, ZONE);
    const eveningToken = await device(evening, ZONE);
    await call("/v1/me", { method: "PATCH", token: evening.token, json: { notifyHour: 20 } });
    const offToken = await device(off, "Asia/Tokyo");
    await call("/v1/me", { method: "PATCH", token: off.token, json: { notifyEnabled: false } });

    const mine = new Set([tokyo.id, toronto.id, evening.id, off.id]);
    const due = (await dueUsers(database(env.DB), now)).filter((u) => mine.has(u.id));
    expect(due.map((u) => u.id).sort()).toEqual([tokyo.id, evening.id, off.id].sort());

    const pushes = (await dailyPushes(database(env.DB), now)).filter((m) =>
      [tokyoToken, eveningToken, offToken].includes(m.deviceToken),
    );
    const kinds = (token: string) => pushes.filter((p) => p.deviceToken === token).map((p) => p.kind);
    expect(kinds(tokyoToken)).toEqual(["background", "alert"]);
    expect(kinds(offToken)).toEqual(["background"]);
    expect(pushes.find((p) => p.deviceToken === tokyoToken && p.kind === "alert")?.body).toBe(
      "0 passes yesterday.",
    );
  });
});

describe("push consumer (E7.35)", () => {
  it("sends through APNs with the right headers and forgets dead tokens", async () => {
    const user = await newUser();
    const good = await device(user, ZONE);
    const dead = await device(user, ZONE);
    const pair = await generateKeyPair("ES256", { extractable: true });
    const configured = {
      ...env,
      APNS_PRIVATE_KEY: await exportPKCS8(pair.privateKey),
      APNS_KEY_ID: "APNSKEY",
    };
    const seen: { url: string; headers: Headers; body: unknown }[] = [];
    const original = deps.fetch;
    deps.fetch = async (input, init) => {
      seen.push({
        url: String(input),
        headers: new Headers(init?.headers),
        body: JSON.parse(String(init?.body)),
      });
      return String(input).includes(dead)
        ? Response.json({ reason: "Unregistered" }, { status: 410 })
        : new Response(null, { status: 200 });
    };
    const acked: string[] = [];
    const message = (body: PushMessage) => ({ body, ack: () => acked.push(body.deviceToken) });
    const batch = {
      messages: [
        message({ deviceToken: good, environment: "sandbox", kind: "alert", body: "1 pass yesterday." }),
        message({ deviceToken: dead, environment: "production", kind: "background" }),
      ],
      ackAll: () => {},
    } as unknown as MessageBatch<PushMessage>;
    try {
      await deliverPushes(batch, configured);
    } finally {
      deps.fetch = original;
    }
    expect(acked).toEqual([good, dead]);
    expect(seen[0]?.url).toBe(`https://api.sandbox.push.apple.com/3/device/${good}`);
    expect(seen[0]?.headers.get("apns-push-type")).toBe("alert");
    expect(seen[0]?.headers.get("apns-priority")).toBe("10");
    expect(seen[0]?.headers.get("apns-topic")).toBe("com.advan.toll");
    expect(seen[0]?.headers.get("authorization")).toMatch(/^bearer ey/);
    expect(seen[0]?.body).toEqual({ aps: { alert: { body: "1 pass yesterday." }, sound: "default" } });
    expect(seen[1]?.url).toBe(`https://api.push.apple.com/3/device/${dead}`);
    expect(seen[1]?.headers.get("apns-push-type")).toBe("background");
    expect(seen[1]?.headers.get("apns-priority")).toBe("5");
    const tokens = await env.DB.prepare(
      "SELECT push_token FROM devices WHERE user_id = ? ORDER BY push_token",
    )
      .bind(user.id)
      .all<{ push_token: string | null }>();
    expect(tokens.results.map((r) => r.push_token).sort()).toEqual([good, null].sort());
  });
});
