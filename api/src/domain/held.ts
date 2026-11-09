export interface GateFact {
  type: string;
  occurredAt: number;
  free: boolean | null;
}

const WAIT_ENDS = new Set(["wait_completed", "wait_abandoned"]);

/**
 * A hit is held when the person walked away: no wait started and no free pass taken within the resume
 * window after it (spec §4 Week stats). A hit while a wait is already running joins that wait (G-5, ledger
 * A21), so it is not a walk-away either. Returns one flag per event, true only for held hits.
 */
export function heldFlags(events: GateFact[], resumeWindowMs: number): boolean[] {
  let waitRunning = false;
  return events.map((event, index) => {
    if (event.type === "wait_started") waitRunning = true;
    else if (WAIT_ENDS.has(event.type) || (event.type === "pass" && event.free === false))
      waitRunning = false;
    if (event.type !== "block_hit" || waitRunning) return false;
    for (let j = index + 1; j < events.length; j++) {
      const next = events[j];
      if (!next || next.occurredAt - event.occurredAt > resumeWindowMs) break;
      if (next.type === "wait_started" || (next.type === "pass" && next.free === true)) return false;
    }
    return true;
  });
}
