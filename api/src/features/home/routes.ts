import { Hono } from "hono";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { loadHome } from "./service";

export const homeRoutes = new Hono<AppEnv>().get("/home", async (c) =>
  c.json(await loadHome(database(c.env.DB), c.env, c.get("userId"))),
);
