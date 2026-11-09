import { describe, expect, it } from "vitest";
import type { AuthSession } from "../src/features/shared/contract";
import { call, env } from "./helpers";
import { lastCodeFor, uniqueEmail } from "./mail";

const start = (email: string) => call("/v1/auth/email/start", { method: "POST", json: { email } });
const verify = (email: string, code: string) =>
  call("/v1/auth/email/verify", { method: "POST", json: { email, code, deviceId: "d1" } });
const wrong = (code: string) => (code === "000000" ? "111111" : "000000");

describe("email sign-in (E3.18)", () => {
  it("signs up with a code, then signs back in to the same account", async () => {
    const email = uniqueEmail();
    expect((await start(` ${email.toUpperCase()} `)).status).toBe(204);
    const first = await verify(email, lastCodeFor(email));
    expect(first.status).toBe(200);
    const session = (await first.json()) as AuthSession;
    expect(session.isNew).toBe(true);
    expect(session.user.email).toBe(email);

    await env.DB.prepare("UPDATE email_codes SET sent_at = 0").run();
    await start(email);
    const second = (await (await verify(email, lastCodeFor(email))).json()) as AuthSession;
    expect(second.isNew).toBe(false);
    expect(second.user.id).toBe(session.user.id);

    expect((await call("/v1/auth/logout", { method: "POST", token: second.token })).status).toBe(204);
    expect((await call("/v1/me", { token: second.token })).status).toBe(401);
    expect((await call("/v1/me", { token: session.token })).status).toBe(200);
  });

  it("rejects a malformed address", async () => {
    const res = await start("not-an-email");
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: "invalid_email" });
  });

  it("enforces the resend cooldown", async () => {
    const email = uniqueEmail();
    await start(email);
    const res = await start(email);
    expect(res.status).toBe(429);
    const body = (await res.json()) as { error: string; retryAt: number };
    expect(body.error).toBe("rate_limited");
    expect(body.retryAt).toBeGreaterThan(Date.now());
  });

  it("counts wrong codes and locks after five, across a resend", async () => {
    const email = uniqueEmail();
    await start(email);
    const code = lastCodeFor(email);
    for (const left of [4, 3]) {
      const res = await verify(email, wrong(code));
      expect(res.status).toBe(400);
      expect(await res.json()).toEqual({ error: "wrong_code", attemptsLeft: left });
    }
    await env.DB.prepare("UPDATE email_codes SET sent_at = 0").run();
    await start(email);
    const fresh = lastCodeFor(email);
    for (const left of [2, 1]) {
      expect(await (await verify(email, wrong(fresh))).json()).toEqual({
        error: "wrong_code",
        attemptsLeft: left,
      });
    }
    const locked = await verify(email, wrong(fresh));
    expect(locked.status).toBe(423);
    const body = (await locked.json()) as { error: string; lockedUntil: number };
    expect(body.error).toBe("locked");
    expect(body.lockedUntil).toBeGreaterThan(Date.now() + 9 * 60_000);
    expect((await verify(email, fresh)).status).toBe(423);
    expect((await start(email)).status).toBe(423);
  });

  it("expires codes after ten minutes", async () => {
    const email = uniqueEmail();
    await start(email);
    await env.DB.prepare("UPDATE email_codes SET expires_at = ?")
      .bind(Date.now() - 1)
      .run();
    const res = await verify(email, lastCodeFor(email));
    expect(res.status).toBe(410);
    expect(await res.json()).toEqual({ error: "expired" });
  });

  it("uses a code only once", async () => {
    const email = uniqueEmail();
    await start(email);
    const code = lastCodeFor(email);
    expect((await verify(email, code)).status).toBe(200);
    expect((await verify(email, code)).status).toBe(410);
  });
});
