import { decodeJwt, decodeProtectedHeader, exportPKCS8, generateKeyPair } from "jose";
import { describe, expect, it } from "vitest";
import { exchangeAuthorizationCode, revokeRefreshToken } from "../src/features/auth/apple";
import type { AuthSession } from "../src/features/shared/contract";
import { deps } from "../src/lib/deps";
import { appleToken, type TokenOptions } from "./apple";
import { call, env } from "./helpers";

describe("Apple token exchange and revoke", () => {
  it("signs a client secret and posts the code, then revokes the refresh token", async () => {
    const pair = await generateKeyPair("ES256", { extractable: true });
    const configured = {
      ...env,
      APPLE_PRIVATE_KEY: await exportPKCS8(pair.privateKey),
      APPLE_KEY_ID: "KEY123",
      APPLE_TEAM_ID: "TEAM123",
    };
    const seen: { url: string; form: URLSearchParams }[] = [];
    const original = deps.fetch;
    deps.fetch = async (input, init) => {
      seen.push({ url: String(input), form: new URLSearchParams(String(init?.body)) });
      return Response.json({ refresh_token: "r-token" });
    };
    try {
      expect(await exchangeAuthorizationCode(configured, "the-code")).toBe("r-token");
      await revokeRefreshToken(configured, "r-token");
    } finally {
      deps.fetch = original;
    }
    expect(seen.map((s) => s.url)).toEqual([
      "https://appleid.apple.com/auth/token",
      "https://appleid.apple.com/auth/revoke",
    ]);
    expect(seen[0]?.form.get("code")).toBe("the-code");
    expect(seen[1]?.form.get("token")).toBe("r-token");
    const secret = seen[0]?.form.get("client_secret") ?? "";
    expect(decodeProtectedHeader(secret)).toMatchObject({ alg: "ES256", kid: "KEY123" });
    expect(decodeJwt(secret)).toMatchObject({
      iss: "TEAM123",
      sub: env.APPLE_BUNDLE_ID,
      aud: "https://appleid.apple.com",
    });
  });

  it("skips the exchange when the key is not configured", async () => {
    expect(await exchangeAuthorizationCode(env, "code")).toBeNull();
  });
});

async function signIn(options: TokenOptions = {}, extra: Record<string, unknown> = {}) {
  const { token, nonce } = await appleToken(options);
  return call("/v1/auth/apple", {
    method: "POST",
    json: { identityToken: token, authorizationCode: "code", nonce, deviceId: "device-1", ...extra },
  });
}

describe("Sign in with Apple (E3.17)", () => {
  it("creates an account on the first sign-in, prefilled from the Apple name", async () => {
    const sub = crypto.randomUUID();
    const res = await signIn(
      { sub, email: "relay@privaterelay.appleid.com" },
      { givenName: "Adit", familyName: "Rahman" },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AuthSession;
    expect(body.isNew).toBe(true);
    expect(body.user.displayName).toBe("Adit Rahman");
    expect(body.user.email).toBe("relay@privaterelay.appleid.com");
    expect(body.user.handle).toBeNull();
    expect(body.user.inviteCode).toMatch(/^[2-9A-HJ-NP-Z]{6}$/);

    const again = (await (await signIn({ sub })).json()) as AuthSession;
    expect(again.isNew).toBe(false);
    expect(again.user.id).toBe(body.user.id);

    const me = await call("/v1/me", { token: again.token });
    expect(((await me.json()) as { id: string }).id).toBe(body.user.id);
  });

  it("rejects a token for another audience", async () => {
    const res = await signIn({ aud: "com.example.other" });
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: "invalid_token" });
  });

  it("rejects a nonce that does not match", async () => {
    expect((await signIn({ nonce: "not-the-hash" })).status).toBe(401);
  });

  it("rejects an expired token", async () => {
    expect((await signIn({ expiresIn: Math.floor(Date.now() / 1000) - 60 })).status).toBe(401);
  });

  it("rejects requests without a session", async () => {
    expect((await call("/v1/me")).status).toBe(401);
    expect((await call("/v1/me", { token: "nope" })).status).toBe(401);
  });
});
