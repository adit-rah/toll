import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import type { AppEnv } from "./env";
import { appRoutes } from "./features/apps/routes";
import { accountRoutes, authRoutes, sessionRoutes } from "./features/auth/routes";
import { eventRoutes } from "./features/events/routes";
import { friendRoutes, publicInviteRoutes } from "./features/friends/routes";
import { homeRoutes } from "./features/home/routes";
import { meRoutes, photoRoutes } from "./features/me/routes";
import { metaRoutes } from "./features/meta/routes";
import { peopleRoutes } from "./features/people/routes";
import { webRoutes } from "./features/web/routes";
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
  app.route("/", webRoutes);

  // Public routes are registered first: Hono runs handlers in registration order, so they answer before the
  // auth middleware below is reached.
  const v1 = new Hono<AppEnv>();
  v1.route("/", metaRoutes);
  v1.route("/", authRoutes);
  v1.route("/", photoRoutes);
  v1.route("/", publicInviteRoutes);
  v1.route("/", accountRoutes);

  const signedIn = new Hono<AppEnv>();
  signedIn.use(requireAuth, idempotency);
  signedIn.route("/", sessionRoutes);
  signedIn.route("/", meRoutes);
  signedIn.route("/", appRoutes);
  signedIn.route("/", eventRoutes);
  signedIn.route("/", friendRoutes);
  signedIn.route("/", homeRoutes);
  signedIn.route("/", peopleRoutes);
  v1.route("/", signedIn);

  app.route("/v1", v1);
  return app;
}
