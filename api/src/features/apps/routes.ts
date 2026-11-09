import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import type { Tag } from "../../config";
import { appRefs, blocksMeta } from "../../db/schema";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { noContent, validate } from "../../lib/http";
import { PutAppRequest, PutBlockRequest, Ref } from "./contract";

const appParam = z.object({ appRef: Ref });
const blockParam = z.object({ blockRef: Ref });

export const appRoutes = new Hono<AppEnv>()
  .get("/apps", async (c) => {
    const rows = await database(c.env.DB)
      .select({ appRef: appRefs.appRef, tag: appRefs.tag })
      .from(appRefs)
      .where(eq(appRefs.userId, c.get("userId")));
    return c.json({ apps: rows.map((r) => ({ appRef: r.appRef, tag: r.tag as Tag })) });
  })
  // Tags are joined at read time, so this one row re-labels every past pass for friends (spec §4).
  .put("/apps/:appRef", validate("param", appParam), validate("json", PutAppRequest), async (c) => {
    const now = Date.now();
    const { tag } = c.req.valid("json");
    await database(c.env.DB)
      .insert(appRefs)
      .values({ userId: c.get("userId"), appRef: c.req.valid("param").appRef, tag, updatedAt: now })
      .onConflictDoUpdate({ target: [appRefs.userId, appRefs.appRef], set: { tag, updatedAt: now } });
    return noContent(c);
  })
  .put("/blocks/:blockRef", validate("param", blockParam), validate("json", PutBlockRequest), async (c) => {
    const now = Date.now();
    const body = c.req.valid("json");
    await database(c.env.DB)
      .insert(blocksMeta)
      .values({
        userId: c.get("userId"),
        blockRef: c.req.valid("param").blockRef,
        schedule: body.schedule,
        appRefs: body.appRefs,
        updatedAt: now,
      })
      .onConflictDoUpdate({
        target: [blocksMeta.userId, blocksMeta.blockRef],
        set: { schedule: body.schedule, appRefs: body.appRefs, updatedAt: now },
      });
    return noContent(c);
  });
