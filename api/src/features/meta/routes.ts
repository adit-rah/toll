import { Hono } from "hono";
import { loadConfig } from "../../config";
import type { AppEnv } from "../../env";

export const metaRoutes = new Hono<AppEnv>()
  .get("/health", (c) => c.json({ ok: true }))
  .get("/config", async (c) => {
    const config = await loadConfig(c.env.CONFIG, c.req.query("v"));
    c.header("cache-control", "public, max-age=300");
    return c.json(config);
  });
