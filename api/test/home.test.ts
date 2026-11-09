import { describe, expect, it } from "vitest";
import { compareByImprovement } from "../src/domain/ordering";
import { isLoosened, type ScheduleShape } from "../src/domain/schedule";
import { addDays, dayStartMs, offsetMinutesIn, tollTimeIn } from "../src/domain/time";
import type { HomeResponse } from "../src/features/home/contract";
import { json, newUser, type TestUser } from "./accounts";
import { DAY, ev, HOUR, MINUTE, upload } from "./events";
import { call, env } from "./helpers";
import { befriend } from "./social";

const ZONE = "America/Toronto";
const tz = (t: number) => offsetMinutesIn(ZONE, t);
const always: ScheduleShape = { kind: "always", start: "00:00", end: "00:00", days: [1, 2, 3, 4, 5, 6, 7] };
const nights: ScheduleShape = { kind: "nights", start: "23:00", end: "07:00", days: [1, 2, 3, 4, 5, 6, 7] };
const weekdays: ScheduleShape = { kind: "weekdays", start: "09:00", end: "17:00", days: [1, 2, 3, 4, 5] };

function clock() {
  const now = Date.now();
  const { week } = tollTimeIn(ZONE, now, 4);
  const weekStart = dayStartMs(week, tz(now), 4);
  const lastWeekNoon = dayStartMs(addDays(week, -7), tz(now), 4) + 8 * HOUR;
  return { now, base: Math.max(now - HOUR, weekStart + MINUTE), lastWeekNoon };
}

async function passes(user: TestUser, count: number, start: number, appRef = "a1") {
  const events = Array.from({ length: count }, (_, i) =>
    ev("pass", start + i * MINUTE, { free: true, appRef, tzOffset: tz(start) }),
  );
  if (events.length) await upload(user, events, "/v1/events/history");
}

describe("schedule coverage and ordering (G-7a, N-3)", () => {
  it("treats any dropped minute as loosened", () => {
    expect(isLoosened(always, nights)).toBe(true);
    expect(isLoosened(nights, always)).toBe(false);
    expect(isLoosened(nights, { ...nights, start: "23:30" })).toBe(true);
    expect(isLoosened(nights, { ...nights, days: [1, 2, 3] })).toBe(true);
    expect(isLoosened(nights, { ...nights, start: "22:00", end: "08:00" })).toBe(false);
    expect(isLoosened(weekdays, { ...weekdays, kind: "custom", days: [1, 2, 3, 4, 5, 6] })).toBe(false);
  });

  it("orders by improvement, null trends last, ties by name", () => {
    const people = [
      { trend: null, name: "Ann" },
      { trend: 0, name: "Bo" },
      { trend: -0.5, name: "Cy" },
      { trend: -0.5, name: "Ab" },
    ];
    expect(people.sort(compareByImprovement).map((p) => p.name)).toEqual(["Ab", "Cy", "Bo", "Ann"]);
  });
});

describe("GET /home (E4.24, N-2…N-5, N-9)", () => {
  it("returns friends in N-3 order with their week, today, passes, blocks and the shared number", async () => {
    const { base, lastWeekNoon } = clock();
    const me = await newUser({ name: "Me Viewer" });
    const bea = await newUser({ name: "Bea" });
    const abe = await newUser({ name: "Abe" });
    const bo = await newUser({ name: "Bo" });
    const cy = await newUser({ name: "Cy" });
    for (const friend of [bea, abe, bo, cy]) await befriend(me, friend);

    await call("/v1/apps/a1", { method: "PUT", token: bea.token, json: { tag: "instagram" } });
    await passes(bea, 4, lastWeekNoon);
    await passes(bea, 1, base);
    await passes(abe, 4, lastWeekNoon);
    await passes(abe, 1, base);
    await passes(bo, 2, lastWeekNoon);
    await passes(bo, 2, base);
    await passes(cy, 3, base);

    const o = { tzOffset: tz(base) };
    await upload(me, [
      ev("block_hit", base, o),
      ev("wait_started", base + 30_000, o),
      ev("wait_abandoned", base + MINUTE, o),
      ev("block_hit", base + 5 * MINUTE, o),
    ]);
    await upload(bea, [ev("block_hit", base + 10 * MINUTE, o), ev("block_hit", base + 20 * MINUTE, o)]);
    await call("/v1/friends/requests", {
      method: "POST",
      token: (await newUser()).token,
      json: { userId: me.id },
    });

    const home = await json<HomeResponse>(call("/v1/home", { token: me.token }));
    expect(home.friends.map((f) => f.user.displayName)).toEqual(["Abe", "Bea", "Bo", "Cy"]);
    const beaRow = home.friends[1];
    expect(beaRow?.week).toMatchObject({ passes: 1, lastWeek: 4, trend: -0.75, hits: 2, held: 2 });
    expect(beaRow?.today.passes).toBe(1);
    expect(beaRow?.today.level).toBe(1);
    expect(beaRow?.todayPasses).toEqual([
      { at: base, tzOffset: tz(base), tag: "instagram", free: true, waitMinutes: 0 },
    ]);
    expect(beaRow?.latestPass?.at).toBe(base);
    expect(home.friends[3]?.week.trend).toBeNull();
    expect(home.friendsHeldPercent).toBe(75);
    expect(home.pendingRequests).toBe(1);

    const seen = await env.DB.prepare("SELECT last_home_at FROM users WHERE id = ?")
      .bind(me.id)
      .first<{ last_home_at: number }>();
    expect(seen?.last_home_at).toBeGreaterThan(Date.now() - 60_000);
  });

  it("pins removals and loosened schedules for 24 hours and silence while it lasts", async () => {
    const { now } = clock();
    const me = await newUser();
    const remover = await newUser({ name: "Remover" });
    const loosener = await newUser({ name: "Loosener" });
    const quiet = await newUser({ name: "Quiet" });
    for (const friend of [remover, loosener, quiet]) await befriend(me, friend);

    await call("/v1/apps/t1", { method: "PUT", token: remover.token, json: { tag: "tiktok" } });
    const t = now - 2 * HOUR;
    const o = { tzOffset: tz(t) };
    await upload(remover, [
      ev("block_added", t - 2 * DAY, { ...o, blockRef: "old", appRefs: ["t1"], schedule: always }),
      ev("block_removed", t - 30 * HOUR, { ...o, blockRef: "old" }),
      ev("block_added", t - HOUR, { ...o, blockRef: "b1", appRefs: ["t1"], schedule: always }),
      ev("block_removed", t + 2 * MINUTE, { ...o, blockRef: "b1" }),
    ]);
    await upload(loosener, [
      ev("block_added", t - HOUR, { ...o, blockRef: "b2", appRefs: ["x1"], schedule: always }),
      ev("block_changed", t, { ...o, blockRef: "b2", oldSchedule: always, schedule: nights }),
      ev("block_changed", t + MINUTE, { ...o, blockRef: "b2", oldSchedule: nights, schedule: always }),
    ]);
    await call("/v1/blocks/q1", {
      method: "PUT",
      token: quiet.token,
      json: { schedule: always, appRefs: [] },
    });
    const quietLast = now - 5 * DAY;
    await upload(quiet, [ev("checkin", quietLast, { tzOffset: tz(quietLast) })]);

    const home = await json<HomeResponse>(call("/v1/home", { token: me.token }));
    expect(home.pinned.map((p) => [p.kind, p.user.displayName])).toEqual([
      ["silence", "Quiet"],
      ["removal", "Remover"],
      ["loosened", "Loosener"],
    ]);
    expect(home.pinned[1]).toMatchObject({ tags: ["tiktok"], schedule: always, since: t + 2 * MINUTE });
    expect(home.pinned[2]).toMatchObject({ tags: [null], schedule: nights, since: t });
    const quietDay = tollTimeIn(ZONE, quietLast, 4).day;
    const quietRow = home.friends.find((f) => f.user.id === quiet.id);
    expect(quietRow?.silentSince).toBe(addDays(quietDay, 1));
    expect(home.pinned[0]?.since).toBe(dayStartMs(addDays(quietDay, 1), tz(now), 4));
    expect(home.friends.find((f) => f.user.id === loosener.id)?.silentSince).toBeNull();
  });
});
