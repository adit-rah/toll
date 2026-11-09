import { PhotonImage } from "@cf-wasm/photon";
import { describe, expect, it } from "vitest";
import type { Me } from "../src/features/shared/contract";
import { json, newUser, uniqueHandle } from "./accounts";
import { call, env } from "./helpers";

const patch = (token: string, body: unknown) => call("/v1/me", { method: "PATCH", token, json: body });

describe("me and handles (E3.19)", () => {
  it("validates display names", async () => {
    const user = await newUser();
    expect(await json(patch(user.token, { displayName: " a " }))).toEqual({ error: "name_invalid" });
    expect(await json(patch(user.token, { displayName: "x".repeat(25) }))).toEqual({ error: "name_invalid" });
    const me = await json<Me>(patch(user.token, { displayName: "  Adit   Rahman " }));
    expect(me.displayName).toBe("Adit Rahman");
  });

  it("enforces handle format and uniqueness", async () => {
    const owner = await newUser();
    const other = await newUser();
    expect(await json(patch(other.token, { handle: "Bad-Handle" }))).toEqual({ error: "handle_invalid" });
    expect(await json(patch(other.token, { handle: "ab" }))).toEqual({ error: "handle_invalid" });
    const taken = await patch(other.token, { handle: owner.handle });
    expect(taken.status).toBe(409);
    expect(await taken.json()).toEqual({ error: "handle_taken" });
  });

  it("lets the first handle be free, then allows one change per cooldown", async () => {
    const user = await newUser();
    const first = await json<Me>(patch(user.token, { handle: uniqueHandle("b") }));
    expect(first.handleChangedAt).not.toBeNull();
    const blocked = await patch(user.token, { handle: uniqueHandle("c") });
    expect(blocked.status).toBe(409);
    const body = (await blocked.json()) as { error: string; availableAt: number };
    expect(body.error).toBe("handle_cooldown");
    expect(body.availableAt).toBe((first.handleChangedAt ?? 0) + 30 * 86_400_000);

    await env.DB.prepare("UPDATE users SET handle_changed_at = ? WHERE id = ?")
      .bind(Date.now() - 31 * 86_400_000, user.id)
      .run();
    expect((await patch(user.token, { handle: uniqueHandle("d") })).status).toBe(200);
  });

  it("checks availability with suggestions that are themselves free", async () => {
    const base = uniqueHandle("adit").slice(0, 12);
    await newUser({ handle: base });
    await newUser({ handle: `${base}2` });
    const viewer = await newUser({ name: "Adit Rahman" });
    const res = await json<{ available: boolean; reason: string; suggestions: string[] }>(
      call(`/v1/handles/${base}/available`, { token: viewer.token }),
    );
    expect(res.available).toBe(false);
    expect(res.reason).toBe("taken");
    expect(res.suggestions).toHaveLength(3);
    expect(res.suggestions).not.toContain(`${base}2`);
    expect(res.suggestions).toContain(`${base}_r`);

    const own = await json<{ available: boolean }>(
      call(`/v1/handles/${viewer.handle}/available`, { token: viewer.token }),
    );
    expect(own.available).toBe(true);
    const invalid = await json<{ reason: string }>(call("/v1/handles/A!/available", { token: viewer.token }));
    expect(invalid.reason).toBe("invalid");
  });

  it("suggests a handle from a name", async () => {
    const viewer = await newUser();
    const name = `Zed${crypto.randomUUID().slice(0, 6).replace(/\d/g, "q")} Rahman`;
    const first = await json<{ handle: string }>(
      call(`/v1/handles/suggest?name=${encodeURIComponent(name)}`, { token: viewer.token }),
    );
    expect(first.handle).toBe(name.split(" ")[0]?.toLowerCase());
    await newUser({ handle: first.handle });
    const second = await json<{ handle: string }>(
      call(`/v1/handles/suggest?name=${encodeURIComponent(name)}`, { token: viewer.token }),
    );
    expect(second.handle).toBe(`${first.handle}_r`);
  });

  it("registers a device and its timezone", async () => {
    const user = await newUser();
    const bad = await call("/v1/devices", {
      method: "PUT",
      token: user.token,
      json: { deviceId: "dev", timezone: "Mars/Olympus" },
    });
    expect(await bad.json()).toEqual({ error: "timezone_invalid" });
    const ok = await call("/v1/devices", {
      method: "PUT",
      token: user.token,
      json: {
        deviceId: `dev-${user.id}`,
        pushToken: "ab".repeat(32),
        pushEnvironment: "sandbox",
        timezone: "Europe/London",
      },
    });
    expect(ok.status).toBe(204);
    expect((await json<Me>(call("/v1/me", { token: user.token }))).timezone).toBe("Europe/London");
  });

  it("stores photos as JPEG no larger than 512 px and replaces the old one", async () => {
    const user = await newUser();
    const pixels = new Uint8Array(600 * 300 * 4).fill(200);
    const png = new PhotonImage(pixels, 600, 300).get_bytes();
    const upload = () =>
      call("/v1/me/photo", {
        method: "PUT",
        token: user.token,
        headers: { "content-type": "image/png" },
        body: png,
      });
    const first = await json<Me>(upload());
    expect(first.photoUrl).toMatch(/^https:\/\/toll\.test\/v1\/photos\/[0-9a-f]{32}\.jpg$/);
    const path = new URL(first.photoUrl ?? "").pathname;
    const served = await call(path);
    expect(served.headers.get("content-type")).toBe("image/jpeg");
    const stored = PhotonImage.new_from_byteslice(new Uint8Array(await served.arrayBuffer()));
    expect([stored.get_width(), stored.get_height()]).toEqual([512, 256]);

    const second = await json<Me>(upload());
    expect(second.photoUrl).not.toBe(first.photoUrl);
    expect((await call(path)).status).toBe(404);

    const removed = await json<Me>(call("/v1/me/photo", { method: "DELETE", token: user.token }));
    expect(removed.photoUrl).toBeNull();
    const junk = await call("/v1/me/photo", {
      method: "PUT",
      token: user.token,
      headers: { "content-type": "image/png" },
      body: new Uint8Array([1, 2, 3]),
    });
    expect(await junk.json()).toEqual({ error: "photo_invalid" });
  });

  it("replays a write with the same Idempotency-Key", async () => {
    const user = await newUser();
    const key = crypto.randomUUID();
    const send = (name: string) =>
      call("/v1/me", {
        method: "PATCH",
        token: user.token,
        headers: { "idempotency-key": key },
        json: { displayName: name },
      });
    expect((await json<Me>(send("First Name"))).displayName).toBe("First Name");
    expect((await json<Me>(send("Second Name"))).displayName).toBe("First Name");
  });
});
