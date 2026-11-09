import { Hono } from "hono";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { fail, noContent, validate } from "../../lib/http";
import { ensureInviteCode } from "../me/service";
import { FriendRequest } from "./contract";
import { acceptRequest, declineRequest, removeFriendship, sendRequest, userByInviteCode } from "./service";

export const inviteUrl = (base: string, code: string) => `${base}/i/${code}`;

export function inviteName(user: { displayName: string | null; handle: string | null }): string {
  return user.displayName ?? (user.handle ? `@${user.handle}` : "");
}

export const publicInviteRoutes = new Hono<AppEnv>().get("/invites/:code", async (c) => {
  const user = await userByInviteCode(database(c.env.DB), c.req.param("code"));
  if (!user) fail(404, "not_found");
  return c.json({ displayName: inviteName(user) });
});

export const friendRoutes = new Hono<AppEnv>()
  .post("/invites", async (c) => {
    const code = await ensureInviteCode(database(c.env.DB), c.get("userId"));
    return c.json({ code, url: inviteUrl(c.env.PUBLIC_BASE_URL, code) });
  })
  .post("/friends/requests", validate("json", FriendRequest), async (c) =>
    c.json(await sendRequest(database(c.env.DB), c.env, c.get("userId"), c.req.valid("json"))),
  )
  .post("/friends/requests/:userId/accept", async (c) => {
    await acceptRequest(database(c.env.DB), c.get("userId"), c.req.param("userId"));
    return noContent(c);
  })
  .post("/friends/requests/:userId/decline", async (c) => {
    await declineRequest(database(c.env.DB), c.get("userId"), c.req.param("userId"));
    return noContent(c);
  })
  .delete("/friends/:userId", async (c) => {
    await removeFriendship(database(c.env.DB), c.get("userId"), c.req.param("userId"));
    return noContent(c);
  });
