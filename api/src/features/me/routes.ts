import { Hono } from "hono";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { loadMe } from "./service";

export const meRoutes = new Hono<AppEnv>().get("/me", async (c) =>
  c.json(await loadMe(database(c.env.DB), c.env, c.get("userId"))),
);
