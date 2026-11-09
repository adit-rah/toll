import { TAGS } from "../../config";
import { median } from "../../domain/status";
import type { Database } from "../../lib/db";

interface MemberWeek {
  school_id: number;
  passes: number;
  hits: number;
  held: number;
}

export interface SchoolWeek {
  schoolId: number;
  week: string;
  activeMembers: number;
  hits: number;
  held: number;
  passesMedian: number;
  passesHistogram: number[];
  byHour: number[];
  tagShare: Record<string, number>;
  examMarks: number;
  computedAt: number;
}

function group<T extends { school_id: number }>(rows: T[]): Map<number, T[]> {
  const out = new Map<number, T[]>();
  for (const row of rows) out.set(row.school_id, [...(out.get(row.school_id) ?? []), row]);
  return out;
}

// Nightly (spec §11.2): one aggregate row per school and week, read by GET /school and /insights/school.
export async function computeSchoolWeek(db: Database, week: string, now = Date.now()): Promise<SchoolWeek[]> {
  const d1 = db.$client;
  const [schools, members, hours, tags, exams] = await d1.batch([
    d1.prepare("SELECT DISTINCT school_id FROM school_memberships"),
    d1
      .prepare(
        `SELECT m.school_id, w.passes, w.hits, w.held FROM school_memberships m
         JOIN rollups_weekly w ON w.user_id = m.user_id AND w.week = ?1 WHERE w.active_days > 0`,
      )
      .bind(week),
    d1
      .prepare(
        `SELECT m.school_id, h.hours FROM school_memberships m
         JOIN hour_histograms h ON h.user_id = m.user_id AND h.week = ?1`,
      )
      .bind(week),
    d1.prepare(
      `SELECT m.school_id, a.tag, COUNT(*) AS n FROM school_memberships m
       JOIN blocks_meta b ON b.user_id = m.user_id, json_each(b.app_refs) j
       JOIN app_refs a ON a.user_id = b.user_id AND a.app_ref = j.value
       GROUP BY m.school_id, a.tag`,
    ),
    d1
      .prepare(
        `SELECT m.school_id, COUNT(*) AS n FROM school_memberships m
         JOIN exam_weeks e ON e.user_id = m.user_id AND e.week = ?1 GROUP BY m.school_id`,
      )
      .bind(week),
  ]);

  const memberRows = group((members?.results ?? []) as unknown as MemberWeek[]);
  const hourRows = group((hours?.results ?? []) as unknown as { school_id: number; hours: string }[]);
  const tagRows = group((tags?.results ?? []) as unknown as { school_id: number; tag: string; n: number }[]);
  const examRows = group((exams?.results ?? []) as unknown as { school_id: number; n: number }[]);

  return ((schools?.results ?? []) as unknown as { school_id: number }[]).map(({ school_id: schoolId }) => {
    const active = memberRows.get(schoolId) ?? [];
    const byHour = Array.from({ length: 24 }, () => 0);
    for (const row of hourRows.get(schoolId) ?? []) {
      (JSON.parse(row.hours) as number[]).forEach((n, h) => {
        byHour[h] = (byHour[h] ?? 0) + n;
      });
    }
    const counted = (tagRows.get(schoolId) ?? []).filter((r) => (TAGS as readonly string[]).includes(r.tag));
    const total = counted.reduce((sum, r) => sum + r.n, 0);
    const tagShare: Record<string, number> = Object.fromEntries(TAGS.map((t) => [t, 0]));
    for (const row of counted) tagShare[row.tag] = total ? row.n / total : 0;
    const passes = active.map((m) => m.passes).sort((a, b) => a - b);
    return {
      schoolId,
      week,
      activeMembers: active.length,
      hits: active.reduce((sum, m) => sum + m.hits, 0),
      held: active.reduce((sum, m) => sum + m.held, 0),
      passesMedian: median(passes),
      // Kept as each member's weekly count, unlabelled, so bins can be cut at read time around the viewer.
      passesHistogram: passes,
      byHour,
      tagShare,
      examMarks: examRows.get(schoolId)?.[0]?.n ?? 0,
      computedAt: now,
    };
  });
}

export async function storeSchoolWeek(db: Database, rows: SchoolWeek[]): Promise<void> {
  const d1 = db.$client;
  const statements = rows.map((r) =>
    d1
      .prepare(
        `INSERT INTO school_rollups_weekly (school_id, week, active_members, hits, held, passes_median,
           passes_histogram, by_hour, tag_share, exam_marks, computed_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
         ON CONFLICT (school_id, week) DO UPDATE SET active_members = ?3, hits = ?4, held = ?5,
           passes_median = ?6, passes_histogram = ?7, by_hour = ?8, tag_share = ?9, exam_marks = ?10,
           computed_at = ?11`,
      )
      .bind(
        r.schoolId,
        r.week,
        r.activeMembers,
        r.hits,
        r.held,
        r.passesMedian,
        JSON.stringify(r.passesHistogram),
        JSON.stringify(r.byHour),
        JSON.stringify(r.tagShare),
        r.examMarks,
        r.computedAt,
      ),
  );
  for (let i = 0; i < statements.length; i += 50) await d1.batch(statements.slice(i, i + 50));
}

export async function refreshSchoolRollups(db: Database, weeks: string[]): Promise<void> {
  for (const week of weeks) await storeSchoolWeek(db, await computeSchoolWeek(db, week));
}
