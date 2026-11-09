import { Hono } from "hono";
import { loadConfig, serverConfig } from "../../config";
import type { AppEnv } from "../../env";

// The app fetches this at launch (spec §11.2). KV reads are edge-cached for the same window, so a change
// to config:v1 reaches every phone within about twice configCacheSeconds.
export const metaRoutes = new Hono<AppEnv>()
  .get("/health", (c) => c.json({ ok: true }))
  .get("/config", async (c) => {
    const config = await loadConfig(c.env.CONFIG, c.req.query("v"));
    c.header("cache-control", `public, max-age=${serverConfig.configCacheSeconds}`);
    return c.json(config);
  });
