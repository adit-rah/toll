import { describe, expect, it } from "vitest";
import { sha256Hex } from "../src/lib/crypto";
import { json, newUser } from "./accounts";
import { call } from "./helpers";
import { befriend, blockDirect } from "./social";

const match = (token: string, hashes: string[]) =>
  json<{ matches: { id: string }[] }>(
    call("/v1/contacts/match", { method: "POST", token, json: { hashes } }),
  );

describe("contacts matching (E4.28, N-12)", () => {
  it("matches salted email hashes of discoverable people only", async () => {
    const me = await newUser();
    const { salt } = await json<{ salt: string }>(call("/v1/contacts/salt", { token: me.token }));
    const [open, hidden, friend, blocker] = [
      await newUser(),
      await newUser(),
      await newUser(),
      await newUser(),
    ];
    await call("/v1/me", { method: "PATCH", token: hidden.token, json: { discoverable: false } });
    await befriend(me, friend);
    await blockDirect(blocker, me);
    const hashFor = (email: string) => sha256Hex(salt + email.toLowerCase());
    const hashes = await Promise.all([open, hidden, friend, blocker, me].map((u) => hashFor(u.email)));
    const { matches } = await match(me.token, [...hashes, "0".repeat(64)]);
    expect(matches.map((m) => m.id)).toEqual([open.id]);
  });

  it("rejects malformed and oversized hash lists", async () => {
    const me = await newUser();
    const bad = await call("/v1/contacts/match", {
      method: "POST",
      token: me.token,
      json: { hashes: ["nothex"] },
    });
    expect(bad.status).toBe(400);
    const tooMany = Array.from({ length: 2001 }, (_, i) => i.toString(16).padStart(64, "0"));
    const big = await call("/v1/contacts/match", {
      method: "POST",
      token: me.token,
      json: { hashes: tooMany },
    });
    expect(big.status).toBe(400);
  });
});
