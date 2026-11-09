import { describe, expect, it } from "vitest";
import { relation } from "../src/domain/visibility";
import type { HomeResponse } from "../src/features/home/contract";
import { database } from "../src/lib/db";
import { json, newUser } from "./accounts";
import { call, env } from "./helpers";
import { outbox } from "./mail";
import { befriend } from "./social";

describe("person blocks and reports (E4.27, N-14, N-15)", () => {
  it("blocks both ways, ends the friendship, and does not restore it on unblock", async () => {
    const [me, other] = [await newUser({ name: "Me" }), await newUser({ name: "Other" })];
    await befriend(me, other);
    expect((await call(`/v1/person-blocks/${other.id}`, { method: "POST", token: me.token })).status).toBe(
      204,
    );
    expect(await relation(database(env.DB), other.id, me.id)).toBe("none");
    expect((await json<HomeResponse>(call("/v1/home", { token: other.token }))).friends).toEqual([]);
    const listed = await json<{ people: { id: string }[] }>(call("/v1/person-blocks", { token: me.token }));
    expect(listed.people.map((p) => p.id)).toEqual([other.id]);
    expect(
      (await json<{ people: unknown[] }>(call("/v1/person-blocks", { token: other.token }))).people,
    ).toEqual([]);

    const retry = await call("/v1/friends/requests", {
      method: "POST",
      token: other.token,
      json: { userId: me.id },
    });
    expect(await retry.json()).toEqual({ error: "not_found" });

    expect((await call(`/v1/person-blocks/${other.id}`, { method: "DELETE", token: me.token })).status).toBe(
      204,
    );
    expect(await relation(database(env.DB), me.id, other.id)).toBe("none");
  });

  it("stores a report and emails the founders", async () => {
    const [me, other] = [await newUser(), await newUser({ name: "Rude Name" })];
    const res = await call("/v1/reports", {
      method: "POST",
      token: me.token,
      json: { userId: other.id, reason: "name", text: "  offensive  " },
    });
    expect(res.status).toBe(204);
    const stored = await env.DB.prepare("SELECT * FROM reports WHERE subject_id = ?").bind(other.id).first();
    expect(stored).toMatchObject({ reporter_id: me.id, reason: "name", text: "offensive" });
    const mail = outbox.at(-1);
    expect(mail?.to).toBe(env.FOUNDERS_EMAIL);
    expect(mail?.subject).toContain("Rude Name");
    const tooLong = await call("/v1/reports", {
      method: "POST",
      token: me.token,
      json: { userId: other.id, reason: "other", text: "x".repeat(501) },
    });
    expect(tooLong.status).toBe(400);
  });
});
