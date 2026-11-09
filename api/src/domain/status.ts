import type { TollConfig } from "../config";

export type Level = 1 | 2 | 3;

// Same rule as TollCore's StatusRules (fixtures/status-levels.json is the contract between them).
export const PERSONALISED_HISTORY_DAYS = 28;
export const MINIMUM_HISTORY_DAYS = 7;

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  if (sorted.length === 0) return 0;
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? ((sorted[mid - 1] ?? 0) + (sorted[mid] ?? 0)) / 2 : (sorted[mid] ?? 0);
}

// `history` is the person's daily pass counts on earlier active days, oldest first.
export function statusLevel(passesToday: number, history: number[], config: TollConfig["status"]): Level {
  if (config.personalise && history.length >= MINIMUM_HISTORY_DAYS) {
    const center = median(history.slice(-PERSONALISED_HISTORY_DAYS));
    const band = Math.max(1, Math.round(center * 0.25));
    if (passesToday < center - band) return 1;
    if (passesToday > center + band) return 3;
    return 2;
  }
  const [low = 2, high = 4] = config.levelBounds;
  if (passesToday <= low) return 1;
  if (passesToday <= high) return 2;
  return 3;
}
