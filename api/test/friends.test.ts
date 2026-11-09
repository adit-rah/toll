import { describe, expect, it } from "vitest";
import { loadGraph, relation } from "../src/domain/visibility";
import { database } from "../src/lib/db";
import { json, newUser } from "./accounts";
import { call, env } from "./helpers";
import { befriend, blockDirect } from "./social";

const db = () => database(env.DB);
const request = (token: string, body: unknown) =>
  call("/v1/friends/requests", { method: "POST", token, json: body });

describe("visibility (E4.22, N-6, N-7, N-14)", () => {
  it("is friend for friends, mutual for friends of friends, none otherwise", async () => {
    const [me, friend, fof, stranger] = await Promise.all([newUser(), newUser(), newUser(), newUser()]);
    await befriend(me, friend);
    await befriend(friend, fof);
    expect(await relation(db(), me.id, friend.id)).toBe("friend");
    expect(await relation(db(), friend.id, me.id)).toBe("friend");
    expect(await relation(db(), me.id, fof.id)).toBe("mutual");
    expect(await relation(db(), fof.id, me.id)).toBe("mutual");
    expect(await relation(db(), me.id, stranger.id)).toBe("none");
    expect(await relation(db(), me.id, me.id)).toBe("none");
  });

  it("hides blocked people both ways, including from mutual counts", async () => {
    const [me, friend, fof] = await Promise.all([newUser(), newUser(), newUser()]);
    await befriend(me, friend);
    await befriend(friend, fof);
    await blockDirect(fof, me);
    expect(await relation(db(), me.id, fof.id)).toBe("none");
    expect(await relation(db(), fof.id, me.id)).toBe("none");
    expect((await loadGraph(db(), me.id)).mutualVia.has(fof.id)).toBe(false);
    expect(await relation(db(), me.id, friend.id)).toBe("friend");
  });

  it("ends visibility both ways when a friend is removed", async () => {
    const [me, friend] = await Promise.all([newUser(), newUser()]);
    await befriend(me, friend);
    expect((await call(`/v1/friends/${me.id}`, { method: "DELETE", token: friend.token })).status).toBe(204);
    expect(await relation(db(), me.id, friend.id)).toBe("none");
    expect(await relation(db(), friend.id, me.id)).toBe("none");
  });
});

describe("friend requests and invites (E4.22, N-2, N-11)", () => {
  it("requests, then accepts on the other side", async () => {
    const [a, b] = await Promise.all([newUser({ name: "Adi Kumar" }), newUser()]);
    const sent = await json<{ status: string; user: { id: string; displayName: string } }>(
      request(a.token, { userId: b.id }),
    );
    expect(sent.status).toBe("requested");
    expect(sent.user.id).toBe(b.id);
    expect((await json<{ status: string }>(request(a.token, { userId: b.id }))).status).toBe("requested");
    expect(
      (await call(`/v1/friends/requests/${b.id}/accept`, { method: "POST", token: a.token })).status,
    ).toBe(404);
    expect(
      (await call(`/v1/friends/requests/${a.id}/accept`, { method: "POST", token: b.token })).status,
    ).toBe(204);
    const again = await request(a.token, { userId: b.id });
    expect(again.status).toBe(409);
    expect(await again.json()).toEqual({ error: "already_friends" });
  });

  it("turns a crossing request into a friendship", async () => {
    const [a, b] = await Promise.all([newUser(), newUser()]);
    await request(a.token, { userId: b.id });
    const crossing = await json<{ status: string }>(request(b.token, { userId: a.id }));
    expect(crossing.status).toBe("accepted");
    expect(await relation(db(), a.id, b.id)).toBe("friend");
  });

  it("declines and cancels without leaving a row", async () => {
    const [a, b] = await Promise.all([newUser(), newUser()]);
    await request(a.token, { userId: b.id });
    expect(
      (await call(`/v1/friends/requests/${a.id}/decline`, { method: "POST", token: b.token })).status,
    ).toBe(204);
    await request(a.token, { userId: b.id });
    expect((await call(`/v1/friends/${b.id}`, { method: "DELETE", token: a.token })).status).toBe(204);
    const rows = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM friendships WHERE user_lo IN (?1, ?2) AND user_hi IN (?1, ?2)",
    )
      .bind(a.id, b.id)
      .first<{ n: number }>();
    expect(rows?.n).toBe(0);
  });

  it("refuses self, unknown and blocked people alike", async () => {
    const [a, b] = await Promise.all([newUser(), newUser()]);
    expect(await json(request(a.token, { userId: a.id }))).toEqual({ error: "self" });
    expect(await json(request(a.token, { userId: "nobody" }))).toEqual({ error: "not_found" });
    expect(await json(request(a.token, { code: "ZZZZZZ" }))).toEqual({ error: "not_found" });
    await blockDirect(b, a);
    expect(await json(request(a.token, { userId: b.id }))).toEqual({ error: "not_found" });
  });

  it("issues one stable invite code and resolves it publicly", async () => {
    const [a, b] = await Promise.all([newUser({ name: "Adit Rahman" }), newUser()]);
    const first = await json<{ code: string; url: string }>(
      call("/v1/invites", { method: "POST", token: a.token }),
    );
    const second = await json<{ code: string }>(call("/v1/invites", { method: "POST", token: a.token }));
    expect(second.code).toBe(first.code);
    expect(first.url).toBe(`https://toll.test/i/${first.code}`);
    expect(await json(call(`/v1/invites/${first.code.toLowerCase()}`))).toEqual({
      displayName: "Adit Rahman",
    });
    expect((await call("/v1/invites/QQQQQQ")).status).toBe(404);

    const viaCode = await json<{ status: string; user: { id: string } }>(
      request(b.token, { code: first.code }),
    );
    expect(viaCode).toMatchObject({ status: "requested", user: { id: a.id } });

    const page = await call(`/i/${first.code}`);
    expect(page.headers.get("content-type")).toContain("text/html");
    expect(await page.text()).toContain("Adit Rahman invited you to Toll");
  });

  it("serves the app-site association for invite links", async () => {
    const res = await call("/.well-known/apple-app-site-association");
    expect(res.headers.get("content-type")).toContain("application/json");
    expect(await res.json()).toEqual({
      applinks: { details: [{ appIDs: ["TESTTEAM00.com.advan.toll"], components: [{ "/": "/i/*" }] }] },
    });
  });
});
