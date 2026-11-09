import { and, eq, inArray, ne } from "drizzle-orm";
import { defaultConfig, serverConfig } from "../../config";
import { copy } from "../../copy";
import { schoolDomains, schoolMemberships, schoolRollupsWeekly, schools } from "../../db/schema";
import { heldPercent } from "../../domain/rollups";
import { domainCandidates } from "../../domain/school";
import { tollTimeIn } from "../../domain/time";
import type { Env } from "../../env";
import { sha256Hex } from "../../lib/crypto";
import type { Database } from "../../lib/db";
import { sendEmail } from "../../lib/email";
import { fail } from "../../lib/http";
import { issueCode, redeemCode } from "../../lib/otp";
import { allowed } from "../../lib/ratelimit";
import { parseEmail } from "../auth/service";
import type { SchoolSummary } from "../people/contract";
import { usersById } from "../shared/people";
import type { SchoolRef } from "./contract";

const schoolKey = async (email: string) => `school:${await sha256Hex(email)}`;

export async function schoolForEmail(db: Database, email: string): Promise<SchoolRef | null> {
  const candidates = domainCandidates(email);
  if (candidates.length === 0) return null;
  const rows = await db
    .select({ domain: schoolDomains.domain, id: schools.id, name: schools.name })
    .from(schoolDomains)
    .innerJoin(schools, eq(schools.id, schoolDomains.schoolId))
    .where(inArray(schoolDomains.domain, candidates));
  // The most specific domain wins ("usjc.uwaterloo.ca" is its own college, not Waterloo).
  const best = candidates.map((d) => rows.find((r) => r.domain === d)).find(Boolean);
  return best ? { id: best.id, name: best.name } : null;
}

export async function startSchool(db: Database, env: Env, rawEmail: string, ip: string): Promise<void> {
  const email = parseEmail(rawEmail);
  const school = await schoolForEmail(db, email);
  if (!school) fail(422, "not_a_school");
  if (!(await allowed(env.RL_OTP, `${ip}:${await sha256Hex(email)}`))) {
    fail(429, "rate_limited", { retryAt: Date.now() + 60_000 });
  }
  const code = await issueCode(db, env, await schoolKey(email), { schoolId: school.id });
  await sendEmail(env, { to: email, ...copy.schoolCode(code, school.name, serverConfig.otpTtlMinutes) });
}

export async function verifySchool(db: Database, env: Env, userId: string, rawEmail: string, code: string) {
  const email = parseEmail(rawEmail);
  const { schoolId } = await redeemCode(db, env, await schoolKey(email), code);
  const [school] = await db
    .select()
    .from(schools)
    .where(eq(schools.id, schoolId ?? -1));
  if (!school) fail(422, "not_a_school");
  const emailHash = await sha256Hex(email);
  const values = { schoolId: school.id, emailHash, verifiedAt: Date.now() };
  // One school email vouches for one account at a time; a newer verification takes it over.
  await db.batch([
    db
      .delete(schoolMemberships)
      .where(and(eq(schoolMemberships.emailHash, emailHash), ne(schoolMemberships.userId, userId))),
    db
      .insert(schoolMemberships)
      .values({ userId, ...values })
      .onConflictDoUpdate({ target: schoolMemberships.userId, set: values }),
  ]);
  return { id: school.id, name: school.name };
}

export async function membership(db: Database, userId: string): Promise<SchoolRef | null> {
  const [row] = await db
    .select({ id: schools.id, name: schools.name })
    .from(schoolMemberships)
    .innerJoin(schools, eq(schools.id, schoolMemberships.schoolId))
    .where(eq(schoolMemberships.userId, userId));
  return row ?? null;
}

export async function schoolWeek(db: Database, schoolId: number, week: string) {
  const [row] = await db
    .select()
    .from(schoolRollupsWeekly)
    .where(and(eq(schoolRollupsWeekly.schoolId, schoolId), eq(schoolRollupsWeekly.week, week)));
  return row ?? null;
}

export const isEnough = (activeMembers: number) => activeMembers >= defaultConfig.network.schoolMinMembers;

export async function viewerWeek(db: Database, userId: string): Promise<string> {
  const user = (await usersById(db, [userId])).get(userId);
  return tollTimeIn(user?.timezone ?? "UTC", Date.now(), defaultConfig.gate.dayResetHour).week;
}

export async function schoolOverview(db: Database, userId: string) {
  const school = await membership(db, userId);
  if (!school) fail(404, "not_found");
  const week = await viewerWeek(db, userId);
  const row = await schoolWeek(db, school.id, week);
  const activeMembers = row?.activeMembers ?? 0;
  const enough = isEnough(activeMembers);
  return {
    school,
    activeMembers,
    enough,
    heldPercent: enough && row ? heldPercent(row.held, row.hits) : null,
    medianPasses: enough && row ? row.passesMedian : null,
    week,
    asOf: row?.computedAt ?? null,
  };
}

export async function schoolSummary(db: Database, userId: string): Promise<SchoolSummary | null> {
  const school = await membership(db, userId);
  if (!school) return null;
  const members = await db.$client
    .prepare("SELECT COUNT(*) AS n FROM school_memberships WHERE school_id = ?")
    .bind(school.id)
    .first<{ n: number }>();
  const row = await schoolWeek(db, school.id, await viewerWeek(db, userId));
  const held = row && isEnough(row.activeMembers) ? heldPercent(row.held, row.hits) : null;
  return { ...school, members: members?.n ?? 0, heldPercent: held };
}
