import { Hono } from "hono";
import { loadGraph } from "../../domain/visibility";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { fail, validate } from "../../lib/http";
import { allowed } from "../../lib/ratelimit";
import { chunked, personRef, usersById } from "../shared/people";
import { ContactsMatchRequest } from "./contract";

export const contactRoutes = new Hono<AppEnv>()
  .get("/contacts/salt", (c) => c.json({ salt: c.env.CONTACTS_SALT }))
  .post("/contacts/match", validate("json", ContactsMatchRequest), async (c) => {
    const viewer = c.get("userId");
    if (!(await allowed(c.env.RL_SOCIAL, viewer))) fail(429, "rate_limited");
    const db = database(c.env.DB);
    const hashes = [...new Set(c.req.valid("json").hashes)];
    const ids = await chunked(hashes, async (chunk) => {
      const marks = chunk.map(() => "?").join(", ");
      const { results } = await db.$client
        .prepare(`SELECT DISTINCT user_id FROM contact_hashes WHERE hash IN (${marks})`)
        .bind(...chunk)
        .all<{ user_id: string }>();
      return results.map((r) => r.user_id);
    });
    const graph = await loadGraph(db, viewer, false);
    const candidates = [...new Set(ids)].filter(
      (id) => id !== viewer && !graph.friends.has(id) && !graph.blocked.has(id),
    );
    const users = await usersById(db, candidates);
    const matches = candidates.flatMap((id) => {
      const user = users.get(id);
      return user?.discoverable && user.handle ? [personRef(c.env, user)] : [];
    });
    return c.json({ matches });
  });
