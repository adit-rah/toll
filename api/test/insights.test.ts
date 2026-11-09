import { describe, expect, it } from "vitest";
import { mergeSmallBins, sturgesBins } from "../src/domain/bins";
import { addDays, dayStartMs, tollTime } from "../src/domain/time";
import type { FriendsInsights, SchoolInsights } from "../src/features/insights/contract";
import { json, newUser, type TestUser } from "./accounts";
import { ev, HOUR, MINUTE, upload } from "./events";
import { call, env } from "./helpers";
import { joinSchool, newSchool } from "./school-fixture";
import { befriend } from "./social";

const week = addDays(tollTime(Date.now(), -300, 4).week, -14);
const tuesdayAt = (hour: number) => dayStartMs(addDays(week, 1), -300, 4) + (hour - 4) * HOUR;

async function lateTikTok(user: TestUser) {
  await call("/v1/apps/tt", { method: "PUT", token: user.token, json: { tag: "tiktok" } });
  await upload(
    user,
    [ev("pass", tuesdayAt(23) + 30 * MINUTE, { appRef: "tt", free: true })],
    "/v1/events/history",
  );
}

describe("bins (insights §7, I-10, I-15)", () => {
  it("uses Sturges' rule capped at maxBins over whole numbers", () => {
    const bins = sturgesBins([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], 8, 4);
    expect(bins.map((b) => [b.from, b.to, b.count])).toEqual([
      [0, 1, 2],
      [2, 3, 2],
      [4, 5, 2],
      [6, 7, 2],
      [8, 9, 2],
    ]);
    expect(bins.findIndex((b) => b.includesMe)).toBe(2);
    expect(
      sturgesBins(
        Array.from({ length: 1000 }, (_, i) => i),
        8,
        null,
      ),
    ).toHaveLength(8);
    expect(sturgesBins([], 8, null)).toEqual([]);
  });

  it("merges small bins into a neighbour until every bin has enough people", () => {
    const merged = mergeSmallBins(
      [
        { from: 0, to: 1, count: 9, includesMe: false },
        { from: 2, to: 3, count: 2, includesMe: true },
        { from: 4, to: 5, count: 6, includesMe: false },
        { from: 6, to: 7, count: 1, includesMe: false },
      ],
      5,
    );
    expect(merged).toEqual([
      { from: 0, to: 1, count: 9, includesMe: false },
      { from: 2, to: 7, count: 9, includesMe: true },
    ]);
  });
});

describe("GET /insights/friends (E8.38, I-10…I-14)", () => {
  it("suppresses the distribution below friendsMinN and names friends only in-app", async () => {
    const me = await newUser({ name: "Me" });
    const [a, b] = [await newUser({ name: "Ann" }), await newUser({ name: "Bob" })];
    await befriend(me, a);
    await befriend(me, b);
    await upload(a, [ev("block_hit", tuesdayAt(12)), ev("block_hit", tuesdayAt(13))], "/v1/events/history");
    await upload(
      b,
      [ev("block_hit", tuesdayAt(12)), ev("wait_started", tuesdayAt(12) + 1000)],
      "/v1/events/history",
    );
    await lateTikTok(a);
    await lateTikTok(b);

    const two = await json<FriendsInsights>(call(`/v1/insights/friends?week=${week}`, { token: me.token }));
    expect(two.distribution).toBeNull();
    expect(two.sameAppSameHour).toBeNull();
    expect(two.people.map((p) => [p.user?.displayName ?? "me", p.heldPercent])).toEqual([
      ["Ann", 100],
      ["Bob", 0],
      ["me", null],
    ]);
    expect(two.people.find((p) => p.isMe)?.user).toBeNull();
    expect(two.friendsHeldPercent).toBe(67);
    expect(two.friendsByHour[23]).toBe(2);
    expect(two.weekly).toHaveLength(8);
    expect(two.weekly.at(-1)).toMatchObject({ week, heldPercent: 67, passesPerPerson: 1 });

    const c = await newUser({ name: "Cy" });
    await befriend(me, c);
    await lateTikTok(c);
    const three = await json<FriendsInsights>(call(`/v1/insights/friends?week=${week}`, { token: me.token }));
    expect(three.distribution?.bins.reduce((sum, bin) => sum + bin.count, 0)).toBe(4);
    expect(three.distribution?.bins.some((bin) => bin.includesMe)).toBe(true);
    expect(three.sameAppSameHour).toEqual({ tag: "tiktok", count: 3 });

    expect((await call("/v1/insights/friends?week=2026-11-10", { token: me.token })).status).toBe(400);
  });
});

describe("GET /insights/school (E8.38, I-15…I-19)", () => {
  it("serves nothing below schoolMinMembers, then merged bins, normalised hours and exam weeks", async () => {
    const school = await newSchool();
    const me = await newUser();
    await joinSchool(me.id, school.id);
    await upload(me, [ev("pass", tuesdayAt(12), { free: true })], "/v1/events/history");
    const insert = (w: string, active: number, histogram: number[], examMarks = 0) =>
      env.DB.prepare(
        `INSERT INTO school_rollups_weekly VALUES (?, ?, ?, 10, 7, 3, ?, ?, '{"tiktok":0.75,"reddit":0.25}', ?, ?)`,
      )
        .bind(
          school.id,
          w,
          active,
          JSON.stringify(histogram),
          JSON.stringify([1, 3, ...Array(22).fill(0)]),
          examMarks,
          1,
        )
        .run();
    await insert(week, 12, Array(12).fill(1));
    const closed = await json<SchoolInsights>(call(`/v1/insights/school?week=${week}`, { token: me.token }));
    expect(closed).toMatchObject({ enough: false, distribution: null, myBin: null, schoolHeldPercent: null });
    expect(closed.school?.id).toBe(school.id);

    await env.DB.prepare("DELETE FROM school_rollups_weekly WHERE school_id = ?").bind(school.id).run();
    const histogram = [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 3, 3, 3, 4, 5, 9, 14, 20, 30];
    await insert(week, histogram.length, histogram, 11);
    await insert(addDays(week, -7), 5, [1, 2, 3, 4, 5], 3);
    const open = await json<SchoolInsights>(call(`/v1/insights/school?week=${week}`, { token: me.token }));
    expect(open.enough).toBe(true);
    expect(open.distribution?.bins.every((bin) => bin.count >= 5)).toBe(true);
    expect(open.distribution?.bins.reduce((sum, bin) => sum + bin.count, 0)).toBe(histogram.length);
    expect(open.myBin).toBe(open.distribution?.bins.findIndex((bin) => bin.includesMe));
    expect(open.myBin).not.toBeNull();
    expect(open.schoolHeldPercent).toBe(70);
    expect(open.byHour.reduce((a, b) => a + b, 0)).toBeCloseTo(1);
    expect(open.byHour[1]).toBeCloseTo(0.75);
    expect(open.tagShare.tiktok).toBe(0.75);
    expect(open.tagShare.youtube).toBe(0);
    expect(open.examWeeks).toEqual([week]);
    expect(open.weekly.at(-2)).toMatchObject({ week: addDays(week, -7), schoolHeldPercent: null });
  });
});
