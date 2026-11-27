"""The buffer suggestion (#145): what each buffer around sleep grows toward, from the person's own weeks.

The reference for the phone's `BufferSuggestion` (TollCore). Both read the same judged weeks: each week
on one side is the buffer most of its lock nights had, and the weekly rule's verdict (D76: smooth, hard,
Screen Time off or hold) from its nights, its pauses in that buffer and Screen Time. The fixtures
(`python -m economy.fixtures`) keep the two equal.

With fewer than `min_weeks` judged weeks on a side, its target is the baseline (D97): 60 before sleep, 30
after waking. Otherwise:
- **A ceiling.** The highest level smooth more often than hard is the person's comfortable level. The
  lowest level above it that was hard at least as often as smooth (and hard at least once) is too much.
  With one, the target is a step below it, never below the comfortable level, never above the baseline.
- **Past the baseline,** before sleep only: the last `raise_smooth_weeks` judged weeks all smooth, at the
  same level at or above the baseline, with no pause in the buffer, and Health's sleep onset at least
  `late_onset_min` after planned sleep (median of at least `health_nights` lock nights). Then one step
  past that level. This is the research's one plausible sign that a longer buffer helps more, and it is
  untested.
- **Otherwise** the baseline.
Always inside the founder's bounds: before sleep 30 to 90, after waking 15 to 30.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

SMOOTH, HARD, OFF, HOLD = "smooth", "hard", "screenTimeOff", "hold"


@dataclass(frozen=True)
class Rule:
    """`TollConfig.suggestion` and the steps of `TollConfig.gap` and `TollConfig.after`."""

    before: int = 60
    after: int = 30
    before_low: int = 30
    before_high: int = 90
    after_low: int = 15
    after_high: int = 30
    min_weeks: int = 4
    lookback_weeks: int = 12
    raise_smooth_weeks: int = 3
    late_onset_min: int = 20
    health_nights: int = 14
    before_step: int = 15
    after_step: int = 15
    # The weekly rule's verdict (`Gap.verdict`, D76).
    smooth_min_nights: int = 4
    smooth_max_pauses: int = 1
    hard_pauses: int = 2

    def bounds(self, side: str) -> tuple[int, int]:
        return (self.before_low, self.before_high) if side == "before" else (self.after_low, self.after_high)


@dataclass(frozen=True)
class Week:
    minutes: int
    verdict: str
    pauses: int


def verdict(nights: int, pauses: int, off: bool, rule: Rule = Rule()) -> str:
    """`Gap.verdict`: the weekly rule's judgement of one week."""
    if off:
        return OFF
    if pauses >= rule.hard_pauses:
        return HARD
    if nights >= rule.smooth_min_nights and pauses <= rule.smooth_max_pauses:
        return SMOOTH
    return HOLD


def late_onset(late: Sequence[int], rule: Rule = Rule()) -> bool:
    """Health's sign: the median of enough lock nights' onset minus planned sleep is late enough."""
    if len(late) < rule.health_nights or not late:
        return False
    s = sorted(late)
    mid = len(s) // 2
    doubled = 2 * s[mid] if len(s) % 2 == 1 else s[mid - 1] + s[mid]
    return doubled >= 2 * rule.late_onset_min


def target(side: str, weeks: Sequence[Week], late: bool, rule: Rule = Rule()) -> int | None:
    """One side's fitted target; None with too few judged weeks, so the baseline stands."""
    low, high = rule.bounds(side)
    baseline = min(max(rule.before if side == "before" else rule.after, low), high)
    step = rule.before_step if side == "before" else rule.after_step
    recent = list(weeks)[-rule.lookback_weeks :] if rule.lookback_weeks > 0 else []
    judged = [w for w in recent if w.minutes > 0 and w.verdict != HOLD]
    if len(judged) < rule.min_weeks:
        return None

    def clamp(m: int) -> int:
        return min(max(m, low), high)

    smooth: dict[int, int] = {}
    hard: dict[int, int] = {}
    for w in judged:
        bucket = smooth if w.verdict == SMOOTH else hard
        bucket[w.minutes] = bucket.get(w.minutes, 0) + 1
    levels = {w.minutes for w in judged}
    ok = [m for m in levels if smooth.get(m, 0) > hard.get(m, 0)]
    comfortable = max(ok) if ok else None
    too_much = [m for m in levels if hard.get(m, 0) >= max(1, smooth.get(m, 0)) and m > (comfortable or 0)]
    if too_much:
        return clamp(min(max(comfortable or 0, min(too_much) - step), baseline))
    last = judged[-rule.raise_smooth_weeks :] if rule.raise_smooth_weeks > 0 else []
    if side == "before" and late and len(last) == rule.raise_smooth_weeks and last:
        top = last[0].minutes
        if top >= baseline and all(w.verdict == SMOOTH and w.pauses == 0 and w.minutes == top for w in last):
            return clamp(top + step)
    return baseline


def suggest(before: Sequence[Week], after: Sequence[Week], late: bool, rule: Rule = Rule()) -> dict:
    """Both sides: the targets and which of them were fitted, as `BufferSuggestion` holds them."""
    out = {"before": rule.before, "after": rule.after, "fitted": []}
    for side, weeks in (("before", before), ("after", after)):
        t = target(side, weeks, late, rule)
        if t is not None:
            out[side] = t
            out["fitted"].append(side)
    return out
