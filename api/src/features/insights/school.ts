import { and, eq, gte, lte } from "drizzle-orm";
import { defaultConfig, serverConfig, TAGS, type Tag } from "../../config";
import { schoolRollupsWeekly } from "../../db/schema";
import { mergeSmallBins, sturgesBins } from "../../domain/bins";
import { heldPercent } from "../../domain/rollups";
import { addDays } from "../../domain/time";
import type { Database } from "../../lib/db";
import { isEnough, membership } from "../school/service";
import type { SchoolInsights } from "./contract";
import { hourRows, sumHours, weeklyRows } from "./data";

const { maxBins, schoolBinMin, examMarkMin } = defaultConfig.insights;

const emptyTags = () => Object.fromEntries(TAGS.map((t) => [t, 0])) as Record<Tag, number>;

// Insights §3.3: served only while the school meets network.schoolMinMembers; otherwise nulls and empties.
export async function schoolInsights(db: Database, viewer: string, week: string): Promise<SchoolInsights> {
  const school = await membership(db, viewer);
  const weeks = Array.from({ length: serverConfig.insightsWeeks }, (_, i) =>
    addDays(week, -7 * (serverConfig.insightsWeeks - 1 - i)),
  );
  const first = weeks[0] ?? week;
  const rows = school
    ? await db
        .select()
        .from(schoolRollupsWeekly)
        .where(
          and(
            eq(schoolRollupsWeekly.schoolId, school.id),
            gte(schoolRollupsWeekly.week, first),
            lte(schoolRollupsWeekly.week, week),
          ),
        )
    : [];
  const current = rows.find((r) => r.week === week);
  const closed: SchoolInsights = {
    enough: false,
    school,
    week,
    asOf: current?.computedAt ?? null,
    distribution: null,
    myBin: null,
    schoolHeldPercent: null,
    myHeldPercent: null,
    weekly: [],
    byHour: Array.from({ length: 24 }, () => 0),
    myByHour: Array.from({ length: 24 }, () => 0),
    tagShare: emptyTags(),
    examWeeks: [],
  };
  if (!school || !current || !isEnough(current.activeMembers)) return closed;

  const [mine, hours] = await Promise.all([
    weeklyRows(db, [viewer], first, week),
    hourRows(db, [viewer], week),
  ]);
  const myWeek = (w: string) => mine.find((r) => r.week === w);
  const me = myWeek(week);
  const myPasses = me && me.active_days > 0 ? me.passes : null;
  const bins = mergeSmallBins(sturgesBins(current.passesHistogram, maxBins, myPasses), schoolBinMin);
  const myBin = bins.findIndex((b) => b.includesMe);
  const total = current.byHour.reduce((sum, n) => sum + n, 0);

  return {
    ...closed,
    enough: true,
    distribution: { bins },
    myBin: myBin === -1 ? null : myBin,
    schoolHeldPercent: heldPercent(current.held, current.hits),
    myHeldPercent: me ? heldPercent(me.held, me.hits) : null,
    weekly: weeks.map((w) => {
      const row = rows.find((r) => r.week === w);
      const open = row && isEnough(row.activeMembers);
      const my = myWeek(w);
      return {
        week: w,
        schoolHeldPercent: open ? heldPercent(row.held, row.hits) : null,
        myHeldPercent: my ? heldPercent(my.held, my.hits) : null,
      };
    }),
    byHour: current.byHour.map((n) => (total ? n / total : 0)),
    myByHour: sumHours([hours.get(viewer)]),
    tagShare: { ...emptyTags(), ...current.tagShare },
    examWeeks: rows.filter((r) => r.examMarks >= examMarkMin).map((r) => r.week),
  };
}
