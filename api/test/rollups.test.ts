import { describe, expect, it } from "vitest";
import { dailyRollups, type StoredEvent } from "../src/domain/rollups";
import { addDays, tollTime } from "../src/domain/time";
import { newUser } from "./accounts";
import { ev, HOUR, MINUTE, upload } from "./events";
import { env } from "./helpers";

const currentWeek = () => tollTime(Date.now(), -300, 4).week;
// Local wall time in UTC-5 on a given Toll day, as an instant.
const at = (day: string, hour: number, minute = 0) =>
  Date.parse(`${day}T${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}:00Z`) + 5 * HOUR;

async function row<T>(sql: string, ...args: unknown[]) {
  return env.DB.prepare(sql)
    .bind(...args)
    .first<T>();
}

describe("rollups (E4.23)", () => {
  it("computes held, abandoned, waits, clean days, trend and hours from ingested events", async () => {
    const user = await newUser();
    const week = addDays(currentWeek(), -14);
    const tue = addDays(week, 1);
    const t = at(tue, 20);
    const thisWeek = [
      ev("block_hit", t, { appRef: "a" }),
      ev("wait_started", t + 30_000),
      ev("wait_abandoned", t + 60_000),
      ev("block_hit", t + HOUR, { appRef: "a" }),
      ev("block_hit", t + 2 * HOUR, { appRef: "a" }),
      ev("pass", t + 2 * HOUR + 60_000, { free: true, appRef: "a" }),
      ev("block_hit", t + 3 * HOUR, { appRef: "a", via: "dismiss" }),
      ev("pass", t + 3 * HOUR + 121_000, { free: true, appRef: "a" }),
      ev("block_hit", t + 4 * HOUR - 10_000, { appRef: "a" }),
      ev("wait_started", t + 4 * HOUR),
      ev("block_hit", t + 4 * HOUR + 5 * MINUTE, { appRef: "a" }),
      ev("wait_completed", t + 4 * HOUR + 8 * MINUTE),
      ev("pass", t + 4 * HOUR + 8 * MINUTE, { free: false, waitMinutes: 8, appRef: "a" }),
      ev("checkin", at(addDays(week, 2), 12)),
    ];
    expect((await upload(user, thisWeek, "/v1/events/history")).body.rejected).toEqual([]);

    const day = await row<Record<string, number>>(
      "SELECT * FROM rollups_daily WHERE user_id = ? AND day = ?",
      user.id,
      tue,
    );
    expect(day).toMatchObject({
      hits: 6,
      held: 2,
      passes: 3,
      free: 2,
      waited: 1,
      wait_minutes: 8,
      abandoned: 1,
      level: 2,
    });

    const weekly = await row<Record<string, number | null>>(
      "SELECT * FROM rollups_weekly WHERE user_id = ? AND week = ?",
      user.id,
      week,
    );
    expect(weekly).toMatchObject({ passes: 3, hits: 6, held: 2, clean_days: 1, active_days: 2, trend: null });

    const lastWeek = addDays(week, -7);
    await upload(
      user,
      Array.from({ length: 6 }, (_, i) => ev("pass", at(addDays(lastWeek, i % 3), 10 + i), { free: true })),
      "/v1/events/history",
    );
    const updated = await row<{ trend: number }>(
      "SELECT trend FROM rollups_weekly WHERE user_id = ? AND week = ?",
      user.id,
      week,
    );
    expect(updated?.trend).toBeCloseTo(-0.5);

    const hours = await row<{ hours: string }>(
      "SELECT hours FROM hour_histograms WHERE user_id = ? AND week = ?",
      user.id,
      week,
    );
    const histogram = JSON.parse(hours?.hours ?? "[]") as number[];
    expect(histogram[22]).toBe(1);
    expect(histogram[23]).toBe(1);
    expect(histogram[0]).toBe(1);
    expect(histogram.reduce((a, b) => a + b, 0)).toBe(3);
  });

  it("puts a pass after midnight and before the reset hour on the previous day", async () => {
    const user = await newUser();
    const week = addDays(currentWeek(), -7);
    const wed = addDays(week, 2);
    await upload(user, [ev("pass", at(addDays(wed, 1), 3, 59), { free: true })], "/v1/events/history");
    const day = await row<{ passes: number }>(
      "SELECT passes FROM rollups_daily WHERE user_id = ? AND day = ?",
      user.id,
      wed,
    );
    expect(day?.passes).toBe(1);
  });

  it("uses each event's own offset across the DST change", () => {
    const events: StoredEvent[] = [
      {
        type: "pass",
        occurredAt: Date.parse("2026-11-01T05:30:00Z"),
        tzOffset: -240,
        free: true,
        waitMinutes: null,
      },
      {
        type: "pass",
        occurredAt: Date.parse("2026-11-01T06:30:00Z"),
        tzOffset: -300,
        free: true,
        waitMinutes: null,
      },
      {
        type: "pass",
        occurredAt: Date.parse("2026-11-01T09:00:00Z"),
        tzOffset: -300,
        free: true,
        waitMinutes: null,
      },
    ];
    const days = dailyRollups(events, 4, 120_000);
    expect(days.get("2026-10-31")?.passes).toBe(2);
    expect(days.get("2026-11-01")?.passes).toBe(1);
  });
});
