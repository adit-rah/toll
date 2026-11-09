import { Hono } from "hono";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { noContent, validate } from "../../lib/http";
import { ReportRequest } from "./contract";
import { blockedByViewer, blockPerson, reportPerson, unblockPerson } from "./service";

// Spec §11.2 names this /blocks/:userId, which collides with /blocks/:blockRef; person blocks live here.
export const safetyRoutes = new Hono<AppEnv>()
  .get("/person-blocks", async (c) =>
    c.json({ people: await blockedByViewer(database(c.env.DB), c.env, c.get("userId")) }),
  )
  .post("/person-blocks/:userId", async (c) => {
    await blockPerson(database(c.env.DB), c.get("userId"), c.req.param("userId"));
    return noContent(c);
  })
  .delete("/person-blocks/:userId", async (c) => {
    await unblockPerson(database(c.env.DB), c.get("userId"), c.req.param("userId"));
    return noContent(c);
  })
  .post("/reports", validate("json", ReportRequest), async (c) => {
    await reportPerson(database(c.env.DB), c.env, c.get("userId"), c.req.valid("json"));
    return noContent(c);
  });
