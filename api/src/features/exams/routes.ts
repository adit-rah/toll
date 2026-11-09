import { and, asc, eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import { examWeeks } from "../../db/schema";
import { isWeekName } from "../../domain/time";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { noContent, validate } from "../../lib/http";

const weekParam = z.object({ week: z.string().refine(isWeekName) });

// Insights I-9 and I-19: a person marks weeks by hand; no detection (ledger C16).
export const examRoutes = new Hono<AppEnv>()
  .get("/exam-weeks", async (c) => {
    const rows = await database(c.env.DB)
      .select({ week: examWeeks.week })
      .from(examWeeks)
      .where(eq(examWeeks.userId, c.get("userId")))
      .orderBy(asc(examWeeks.week));
    return c.json({ weeks: rows.map((r) => r.week) });
  })
  .put("/exam-weeks/:week", validate("param", weekParam), async (c) => {
    await database(c.env.DB)
      .insert(examWeeks)
      .values({ userId: c.get("userId"), week: c.req.valid("param").week })
      .onConflictDoNothing();
    return noContent(c);
  })
  .delete("/exam-weeks/:week", validate("param", weekParam), async (c) => {
    await database(c.env.DB)
      .delete(examWeeks)
      .where(and(eq(examWeeks.userId, c.get("userId")), eq(examWeeks.week, c.req.valid("param").week)));
    return noContent(c);
  });
