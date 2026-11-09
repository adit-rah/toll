import { describe, expect, it } from "vitest";
import dayMath from "../../fixtures/day-math.json";
import statusLevels from "../../fixtures/status-levels.json";
import { statusLevel } from "../src/domain/status";
import { addDays, isWeekName, offsetMinutesIn, tollTime, tollTimeIn, weekOf } from "../src/domain/time";

describe("day math (fixtures/day-math.json)", () => {
  for (const { name, input, expected } of dayMath.cases) {
    it(name, () => {
      const at = Date.parse(input.instant);
      const fromOffset = tollTime(at, input.offsetMinutes, input.resetHour);
      expect({ day: fromOffset.day, week: fromOffset.week, hour: fromOffset.hour }).toEqual(expected);
      expect(offsetMinutesIn(input.timeZone, at)).toBe(input.offsetMinutes);
      const fromZone = tollTimeIn(input.timeZone, at, input.resetHour);
      expect({ day: fromZone.day, week: fromZone.week, hour: fromZone.hour }).toEqual(expected);
    });
  }

  it("does calendar arithmetic across months and years", () => {
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
    expect(addDays("2024-03-01", -1)).toBe("2024-02-29");
    expect(weekOf("2027-01-03")).toBe("2026-12-28");
    expect(isWeekName("2026-11-09")).toBe(true);
    expect(isWeekName("2026-11-10")).toBe(false);
  });
});

describe("status levels (fixtures/status-levels.json)", () => {
  for (const { name, input, expected } of statusLevels.cases) {
    it(name, () => {
      expect(statusLevel(input.passesToday, input.history, statusLevels.config)).toBe(expected);
    });
  }
});
