import { Hono } from "hono";
import type { AppEnv } from "../../env";
import { bearer } from "../../lib/auth";
import { database } from "../../lib/db";
import { noContent, validate } from "../../lib/http";
import { AppleSignInRequest, EmailStartRequest, EmailVerifyRequest } from "./contract";
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

export const sessionRoutes = new Hono<AppEnv>().post("/auth/logout", async (c) => {
  const token = bearer(c.req.header("authorization"));
  if (token) await endSession(database(c.env.DB), token);
  return noContent(c);
});
