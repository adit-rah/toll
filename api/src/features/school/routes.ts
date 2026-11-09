import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { schoolMemberships } from "../../db/schema";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { noContent, validate } from "../../lib/http";
import { SchoolStartRequest, SchoolVerifyRequest } from "./contract";
import { schoolMembers } from "./members";
import { schoolOverview, startSchool, verifySchool } from "./service";

export const schoolRoutes = new Hono<AppEnv>()
  .post("/school/start", validate("json", SchoolStartRequest), async (c) => {
    const ip = c.req.header("cf-connecting-ip") ?? "unknown";
    await startSchool(database(c.env.DB), c.env, c.req.valid("json").email, ip);
    return noContent(c);
  })
  .post("/school/verify", validate("json", SchoolVerifyRequest), async (c) => {
    const { email, code } = c.req.valid("json");
    return c.json(await verifySchool(database(c.env.DB), c.env, c.get("userId"), email, code));
  })
  .delete("/school", async (c) => {
    await database(c.env.DB)
      .delete(schoolMemberships)
      .where(eq(schoolMemberships.userId, c.get("userId")));
    return noContent(c);
  })
  .get("/school", async (c) => c.json(await schoolOverview(database(c.env.DB), c.get("userId"))))
  .get("/school/members", async (c) =>
    c.json(await schoolMembers(database(c.env.DB), c.env, c.get("userId"))),
  );
