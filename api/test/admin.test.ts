import { describe, expect, it } from "vitest";
import { json, newUser } from "./accounts";
import { call, env } from "./helpers";
import { befriend } from "./social";

interface Stats {
  installs: number;
  users: number;
  usersWithFriend: number;
  weeklyLookers: number;
  usersWithFriendPercent: number;
}

const stats = () => json<Stats>(call("/v1/admin/stats", { token: env.ADMIN_TOKEN }));

describe("admin stats (E11.51, spec §1)", () => {
  it("refuses app sessions and wrong tokens", async () => {
    const user = await newUser();
    expect((await call("/v1/admin/stats", { token: user.token })).status).toBe(401);
    expect((await call("/v1/admin/stats")).status).toBe(401);
  });

  it("counts installs, users, users with a friend and weekly lookers", async () => {
    const before = await stats();
    const [a, b, c] = [await newUser(), await newUser(), await newUser()];
    await befriend(a, b);
    await call("/v1/devices", {
      method: "PUT",
      token: c.token,
      json: { deviceId: crypto.randomUUID(), timezone: "UTC" },
    });
    await call("/v1/home", { token: a.token });
    const after = await stats();
    expect(after.users - before.users).toBe(3);
    expect(after.usersWithFriend - before.usersWithFriend).toBe(2);
    expect(after.installs - before.installs).toBe(1);
    expect(after.weeklyLookers - before.weeklyLookers).toBe(1);
    expect(after.usersWithFriendPercent).toBe(Math.round((100 * after.usersWithFriend) / after.users));
  });
});
