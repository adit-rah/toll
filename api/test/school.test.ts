import { describe, expect, it } from "vitest";
import { domainCandidates } from "../src/domain/school";
import { tollTimeIn } from "../src/domain/time";
import type { SchoolMembersResponse } from "../src/features/school/contract";
import { computeSchoolWeek, refreshSchoolRollups } from "../src/features/school/rollups";
import type { Me } from "../src/features/shared/contract";
import { database } from "../src/lib/db";
import { json, newUser } from "./accounts";
import { ev, upload } from "./events";
import { call, env } from "./helpers";
import { lastCodeFor } from "./mail";
import { joinSchool, newSchool, USJC, WATERLOO } from "./school-fixture";
import { befriend, blockDirect } from "./social";

const start = (token: string, email: string) =>
  call("/v1/school/start", { method: "POST", token, json: { email } });
const verify = (token: string, email: string, code: string) =>
  call("/v1/school/verify", { method: "POST", token, json: { email, code } });

describe("school suffix matching (N-8)", () => {
  it("walks up the labels of the domain", () => {
    expect(domainCandidates("a@cs.uwaterloo.ca")).toEqual(["cs.uwaterloo.ca", "uwaterloo.ca"]);
    expect(domainCandidates("a@Mail.UToronto.ca")).toEqual(["mail.utoronto.ca", "utoronto.ca"]);
    expect(domainCandidates("nobody")).toEqual([]);
  });

  it("verifies a departmental address against its school, most specific domain first", async () => {
    const user = await newUser();
    const email = `adit-${crypto.randomUUID().slice(0, 6)}@cs.uwaterloo.ca`;
    expect((await start(user.token, email)).status).toBe(204);
    const joined = await json<{ id: number; name: string }>(verify(user.token, email, lastCodeFor(email)));
    expect(joined).toEqual(WATERLOO);
    expect((await json<Me>(call("/v1/me", { token: user.token }))).school).toEqual(WATERLOO);

    const jerome = `j-${crypto.randomUUID().slice(0, 6)}@usjc.uwaterloo.ca`;
    await start(user.token, jerome);
    expect(await json(verify(user.token, jerome, lastCodeFor(jerome)))).toEqual(USJC);

    expect((await call("/v1/school", { method: "DELETE", token: user.token })).status).toBe(204);
    expect((await json<Me>(call("/v1/me", { token: user.token }))).school).toBeNull();
  });

  it("refuses unknown domains", async () => {
    const user = await newUser();
    const res = await start(user.token, "someone@gmail.com");
    expect(res.status).toBe(422);
    expect(await res.json()).toEqual({ error: "not_a_school" });
  });

  it("moves a school email to the account that verified it last", async () => {
    const [first, second] = [await newUser(), await newUser()];
    const email = `shared-${crypto.randomUUID().slice(0, 6)}@uwaterloo.ca`;
    for (const user of [first, second]) {
      await env.DB.prepare("UPDATE email_codes SET sent_at = 0").run();
      await start(user.token, email);
      await verify(user.token, email, lastCodeFor(email));
    }
    expect((await json<Me>(call("/v1/me", { token: first.token }))).school).toBeNull();
    expect((await json<Me>(call("/v1/me", { token: second.token }))).school).toEqual(WATERLOO);
  });
});

describe("school aggregates and members (E4.26)", () => {
  it("computes weekly aggregates from active members and holds them back below the minimum", async () => {
    const school = await newSchool();
    const users = [await newUser(), await newUser(), await newUser()];
    const week = tollTimeIn("America/Toronto", Date.now(), 4).week;
    const t = Date.now() - 60_000;
    for (const [i, user] of users.entries()) {
      await joinSchool(user.id, school.id);
      await call("/v1/apps/a1", {
        method: "PUT",
        token: user.token,
        json: { tag: i < 2 ? "tiktok" : "reddit" },
      });
      await call("/v1/blocks/b1", {
        method: "PUT",
        token: user.token,
        json: {
          schedule: { kind: "always", start: "00:00", end: "00:00", days: [1, 2, 3, 4, 5, 6, 7] },
          appRefs: ["a1"],
        },
      });
      const passes = Array.from({ length: i * 2 }, (_, n) =>
        ev("pass", t - n * 1000, { free: true, tzOffset: -300 }),
      );
      await upload(user, [ev("block_hit", t - 5000, { tzOffset: -300 }), ...passes]);
    }
    await env.DB.prepare("INSERT INTO exam_weeks VALUES (?, ?)").bind(users[0]?.id, week).run();

    const [row] = (await computeSchoolWeek(database(env.DB), week)).filter((r) => r.schoolId === school.id);
    expect(row).toMatchObject({
      activeMembers: 3,
      hits: 3,
      held: 1,
      passesMedian: 2,
      passesHistogram: [0, 2, 4],
      examMarks: 1,
    });
    expect(row?.tagShare.tiktok).toBeCloseTo(2 / 3);
    expect(row?.byHour.reduce((a, b) => a + b, 0)).toBe(6);

    await refreshSchoolRollups(database(env.DB), [week]);
    const overview = await json<{
      enough: boolean;
      activeMembers: number;
      heldPercent: number | null;
      asOf: number;
    }>(call("/v1/school", { token: users[0]?.token }));
    expect(overview).toMatchObject({
      enough: false,
      activeMembers: 3,
      heldPercent: null,
      medianPasses: null,
    });
    expect(overview.asOf).toBeGreaterThan(0);

    await env.DB.prepare("UPDATE school_rollups_weekly SET active_members = 25 WHERE school_id = ?")
      .bind(school.id)
      .run();
    const enough = await json<{ enough: boolean; heldPercent: number; medianPasses: number }>(
      call("/v1/school", { token: users[0]?.token }),
    );
    expect(enough).toMatchObject({ enough: true, heldPercent: 33, medianPasses: 2 });
  });

  it("lists members with their relation, hiding blocked people and strangers' photos and levels", async () => {
    const school = await newSchool();
    const me = await newUser({ name: "Me" });
    const friend = await newUser({ name: "Friend" });
    const mutual = await newUser({ name: "Mutual" });
    const asked = await newUser({ name: "Asked" });
    const stranger = await newUser({ name: "Stranger" });
    const blocked = await newUser({ name: "Blocked" });
    for (const user of [me, friend, mutual, asked, stranger, blocked]) await joinSchool(user.id, school.id);
    await befriend(me, friend);
    await befriend(friend, mutual);
    await call("/v1/friends/requests", { method: "POST", token: me.token, json: { userId: asked.id } });
    await blockDirect(blocked, me);

    const { members } = await json<SchoolMembersResponse>(call("/v1/school/members", { token: me.token }));
    expect(members.map((m) => [m.user.displayName, m.relation])).toEqual([
      ["Friend", "friend"],
      ["Mutual", "mutual"],
      ["Asked", "requested"],
      ["Stranger", "none"],
    ]);
    const strangerRow = members.find((m) => m.relation === "none");
    expect(strangerRow?.user.handle).toBe(stranger.handle);
    expect(strangerRow?.level).toBeNull();
    expect(strangerRow?.user.photoUrl).toBeNull();
  });
});
