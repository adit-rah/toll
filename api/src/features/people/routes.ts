import { Hono } from "hono";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { schoolSummary } from "../school/service";
import { loadPeople } from "./service";

export const peopleRoutes = new Hono<AppEnv>().get("/people", async (c) =>
  c.json(await loadPeople(database(c.env.DB), c.env, c.get("userId"), schoolSummary)),
);
