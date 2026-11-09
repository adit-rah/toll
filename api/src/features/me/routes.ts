import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import { serverConfig } from "../../config";
import { users } from "../../db/schema";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { fail, noContent, validate } from "../../lib/http";
import { DeviceRequest, PatchMeRequest } from "./contract";
import { checkHandle, suggestHandle } from "./handles";
import { replacePhoto, servePhoto, swapPhotoKey } from "./photo";
import { loadMe } from "./service";
import { patchMe, registerDevice } from "./update";

export const photoRoutes = new Hono<AppEnv>().get("/photos/:key", async (c) => {
  const res = await servePhoto(c.env, c.req.param("key"));
  if (!res) fail(404, "not_found");
  return res;
});

export const meRoutes = new Hono<AppEnv>()
  .get("/me", async (c) => c.json(await loadMe(database(c.env.DB), c.env, c.get("userId"))))
  .patch("/me", validate("json", PatchMeRequest), async (c) => {
    const db = database(c.env.DB);
    await patchMe(db, c.get("userId"), c.req.valid("json"));
    return c.json(await loadMe(db, c.env, c.get("userId")));
  })
  .get("/handles/suggest", validate("query", z.object({ name: z.string().max(200) })), async (c) => {
    const handle = await suggestHandle(database(c.env.DB), c.req.valid("query").name, c.get("userId"));
    return c.json({ handle });
  })
  .get("/handles/:handle/available", async (c) => {
    const db = database(c.env.DB);
    const [viewer] = await db
      .select({ id: users.id, displayName: users.displayName })
      .from(users)
      .where(eq(users.id, c.get("userId")));
    if (!viewer) fail(401, "unauthorized");
    return c.json(await checkHandle(db, c.req.param("handle"), viewer));
  })
  .put("/me/photo", async (c) => {
    const db = database(c.env.DB);
    const declared = Number(c.req.header("content-length") ?? 0);
    if (declared > serverConfig.photoMaxUploadBytes) fail(413, "photo_too_large");
    const type = (c.req.header("content-type") ?? "").split(";")[0]?.trim() ?? "";
    await replacePhoto(db, c.env, c.get("userId"), type, await c.req.arrayBuffer());
    return c.json(await loadMe(db, c.env, c.get("userId")));
  })
  .delete("/me/photo", async (c) => {
    const db = database(c.env.DB);
    await swapPhotoKey(db, c.env, c.get("userId"), null);
    return c.json(await loadMe(db, c.env, c.get("userId")));
  })
  .put("/devices", validate("json", DeviceRequest), async (c) => {
    await registerDevice(database(c.env.DB), c.get("userId"), c.req.valid("json"));
    return noContent(c);
  });
