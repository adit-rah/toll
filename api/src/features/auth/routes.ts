import { Hono } from "hono";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { validate } from "../../lib/http";
import { AppleSignInRequest } from "./contract";
import { signInWithApple } from "./service";

export const authRoutes = new Hono<AppEnv>().post(
  "/auth/apple",
  validate("json", AppleSignInRequest),
  async (c) => c.json(await signInWithApple(database(c.env.DB), c.env, c.req.valid("json"))),
);
