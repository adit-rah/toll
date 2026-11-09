import { Hono } from "hono";
import type { AppEnv } from "../../env";
import { bearer, requireAuth } from "../../lib/auth";
import { database } from "../../lib/db";
import { noContent, validate } from "../../lib/http";
import { AppleSignInRequest, DeleteAccountRequest, EmailStartRequest, EmailVerifyRequest } from "./contract";
import { deleteAccount } from "./delete";
import { endSession, parseEmail, sendSignInCode, signInWithApple, signInWithEmail } from "./service";

export const authRoutes = new Hono<AppEnv>()
  .post("/auth/apple", validate("json", AppleSignInRequest), async (c) =>
    c.json(await signInWithApple(database(c.env.DB), c.env, c.req.valid("json"))),
  )
  .post("/auth/email/start", validate("json", EmailStartRequest), async (c) => {
    const email = parseEmail(c.req.valid("json").email);
    await sendSignInCode(database(c.env.DB), c.env, email, c.req.header("cf-connecting-ip") ?? "unknown");
    return noContent(c);
  })
  .post("/auth/email/verify", validate("json", EmailVerifyRequest), async (c) =>
    c.json(await signInWithEmail(database(c.env.DB), c.env, c.req.valid("json"))),
  );

// Outside the idempotency layer on purpose: it would write a replay row for a user that no longer exists.
export const accountRoutes = new Hono<AppEnv>().delete(
  "/account",
  requireAuth,
  validate("json", DeleteAccountRequest),
  async (c) => {
    await deleteAccount(database(c.env.DB), c.env, c.get("userId"), c.req.valid("json").reauth);
    return noContent(c);
  },
);

export const sessionRoutes = new Hono<AppEnv>().post("/auth/logout", async (c) => {
  const token = bearer(c.req.header("authorization"));
  if (token) await endSession(database(c.env.DB), token);
  return noContent(c);
});
