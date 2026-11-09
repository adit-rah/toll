import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import type { AppEnv } from "./env";
import { authRoutes, sessionRoutes } from "./features/auth/routes";
import { meRoutes, photoRoutes } from "./features/me/routes";
import { metaRoutes } from "./features/meta/routes";
import { requireAuth } from "./lib/auth";
import { idempotency } from "./lib/idempotency";

export function createApp() {
  const app = new Hono<AppEnv>();

  app.onError((err, c) => {
    if (err instanceof HTTPException) return err.getResponse();
    console.error(err);
    return c.json({ error: "internal" }, 500);
  });

  app.get("/health", (c) => c.json({ ok: true }));

  // Public routes are registered first: Hono runs handlers in registration order, so they answer before the
  // auth middleware below is reached.
  const v1 = new Hono<AppEnv>();
  v1.route("/", metaRoutes);
  v1.route("/", authRoutes);
  v1.route("/", photoRoutes);

  const signedIn = new Hono<AppEnv>();
  signedIn.use(requireAuth, idempotency);
  signedIn.route("/", sessionRoutes);
  signedIn.route("/", meRoutes);
  v1.route("/", signedIn);

  app.route("/v1", v1);
  return app;
}
