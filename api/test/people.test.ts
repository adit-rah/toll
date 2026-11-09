import { describe, expect, it } from "vitest";
import type { PeopleResponse } from "../src/features/people/contract";
import { json, newUser } from "./accounts";
import { ev, upload } from "./events";
import { call } from "./helpers";
import { befriend, blockDirect } from "./social";

describe("GET /people and mutuals (E4.25, N-7)", () => {
  it("lists requests with shared friends, outgoing, friends and mutuals with level and trend only", async () => {
    const me = await newUser({ name: "Me" });
    const adi = await newUser({ name: "Adi" });
    const bea = await newUser({ name: "Bea" });
    const cy = await newUser({ name: "Cy" });
    const mutual = await newUser({ name: "Mutual" });
    const asker = await newUser({ name: "Asker" });
    const asked = await newUser({ name: "Asked" });
    const blocked = await newUser({ name: "Blocked" });
    for (const friend of [adi, bea, cy]) await befriend(me, friend);
    for (const friend of [adi, bea, cy]) await befriend(friend, mutual);
    await befriend(adi, asker);
    await befriend(bea, asked);
    await befriend(adi, blocked);
    await blockDirect(me, blocked);
    await call("/v1/friends/requests", { method: "POST", token: asker.token, json: { userId: me.id } });
    await call("/v1/friends/requests", { method: "POST", token: me.token, json: { userId: asked.id } });
    await upload(mutual, [ev("pass", Date.now() - 1000, { free: true, appRef: "secret" })]);

    const people = await json<PeopleResponse>(call("/v1/people", { token: me.token }));
    expect(people.requests.map((r) => [r.user.displayName, r.mutualNames])).toEqual([["Asker", ["Adi"]]]);
    expect(people.outgoing.map((p) => p.displayName)).toEqual(["Asked"]);
    expect(people.friends.map((f) => f.user.displayName).sort()).toEqual(["Adi", "Bea", "Cy"]);
    expect(people.mutuals).toHaveLength(1);
    const row = people.mutuals[0];
    expect(row?.user.displayName).toBe("Mutual");
    expect(row?.via).toEqual(["Adi"]);
    expect(row?.viaCount).toBe(3);
    expect(row?.level).toBe(1);
    expect(Object.keys(row ?? {}).sort()).toEqual(["level", "trend", "user", "via", "viaCount"]);
    expect(JSON.stringify(people)).not.toContain("Blocked");
  });

  it("drops a mutual who blocked you", async () => {
    const me = await newUser();
    const friend = await newUser();
    const other = await newUser();
    await befriend(me, friend);
    await befriend(friend, other);
    expect((await json<PeopleResponse>(call("/v1/people", { token: me.token }))).mutuals).toHaveLength(1);
    await blockDirect(other, me);
    expect((await json<PeopleResponse>(call("/v1/people", { token: me.token }))).mutuals).toEqual([]);
  });
});
