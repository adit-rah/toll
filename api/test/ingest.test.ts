import { describe, expect, it } from "vitest";
import { json, newUser } from "./accounts";
import { DAY, ev, upload } from "./events";
import { call, env } from "./helpers";

const countEvents = async (userId: string) =>
  (
    await env.DB.prepare("SELECT COUNT(*) AS n FROM events WHERE user_id = ?")
      .bind(userId)
      .first<{ n: number }>()
  )?.n;

const nights = { kind: "nights" as const, start: "23:00", end: "07:00", days: [1, 2, 3, 4, 5, 6, 7] };

describe("event ingest (E2.15 server side, E3.21)", () => {
  it("is idempotent: the same batch twice stores one row and accepts both times", async () => {
    const user = await newUser();
    const batch = [
      ev("block_hit", Date.now() - 1000, { appRef: "a1", via: "open" }),
      ev("checkin", Date.now()),
    ];
    const first = await upload(user, batch);
    const second = await upload(user, batch);
    expect(first.body.accepted).toEqual(batch.map((e) => e.id));
    expect(second.body.accepted).toEqual(batch.map((e) => e.id));
    expect(await countEvents(user.id)).toBe(2);
  });

  it("rejects skewed and malformed events without failing the batch", async () => {
    const user = await newUser();
    const ok = ev("checkin", Date.now());
    const old = ev("checkin", Date.now() - 8 * DAY);
    const future = ev("checkin", Date.now() + 8 * DAY);
    const { body } = await upload(user, [
      ok,
      old,
      future,
      { ...ev("pass", Date.now()), type: "nope" as never },
    ]);
    expect(body.accepted).toEqual([ok.id]);
    expect(body.rejected.map((r) => r.reason)).toEqual(["skew", "skew", "invalid"]);
  });

  it("accepts older history on the history endpoint, up to retention", async () => {
    const user = await newUser();
    const month = ev("pass", Date.now() - 30 * DAY, { free: true, appRef: "a1" });
    const ancient = ev("pass", Date.now() - 91 * DAY, { free: true, appRef: "a1" });
    expect((await upload(user, [month])).body.rejected).toHaveLength(1);
    const { body } = await upload(user, [month, ancient], "/v1/events/history");
    expect(body.accepted).toEqual([month.id]);
    expect(body.rejected).toEqual([{ id: ancient.id, reason: "skew" }]);
  });

  it("keeps blocks_meta in step with block events and keeps the removed block's apps", async () => {
    const user = await newUser();
    const t = Date.now() - 10_000;
    await upload(user, [ev("block_added", t, { blockRef: "b1", appRefs: ["a1", "a2"], schedule: nights })]);
    const meta = await env.DB.prepare("SELECT * FROM blocks_meta WHERE user_id = ?").bind(user.id).all();
    expect(meta.results).toHaveLength(1);

    const removal = ev("block_removed", t + 1000, { blockRef: "b1" });
    await upload(user, [removal]);
    expect(
      (await env.DB.prepare("SELECT * FROM blocks_meta WHERE user_id = ?").bind(user.id).all()).results,
    ).toEqual([]);
    const stored = await env.DB.prepare("SELECT payload FROM events WHERE event_id = ?")
      .bind(removal.id)
      .first<{ payload: string }>();
    expect(JSON.parse(stored?.payload ?? "{}").appRefs).toEqual(["a1", "a2"]);

    await upload(user, [ev("block_changed", t + 500, { blockRef: "b1", schedule: nights })]);
    expect(
      (await env.DB.prepare("SELECT * FROM blocks_meta WHERE user_id = ?").bind(user.id).all()).results,
    ).toEqual([]);
  });

  it("stores tags by app ref and blocks without names", async () => {
    const user = await newUser();
    expect(
      (await call("/v1/apps/a1", { method: "PUT", token: user.token, json: { tag: "tiktok" } })).status,
    ).toBe(204);
    await call("/v1/apps/a1", { method: "PUT", token: user.token, json: { tag: "instagram" } });
    expect(await json(call("/v1/apps", { token: user.token }))).toEqual({
      apps: [{ appRef: "a1", tag: "instagram" }],
    });
    const bad = await call("/v1/apps/a1", { method: "PUT", token: user.token, json: { tag: "facebook" } });
    expect(bad.status).toBe(400);
    const block = await call("/v1/blocks/b9", {
      method: "PUT",
      token: user.token,
      json: { schedule: nights, appRefs: ["a1"] },
    });
    expect(block.status).toBe(204);
  });
});
