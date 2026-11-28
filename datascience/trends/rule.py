"""Your sleep's trend rule (D104, #165): the reference for TollCore's `SleepTrends`.

A night is a day number (day 0 is a Monday night) and a value. `now` is the night key of the moment the
screen is read: the day twelve hours earlier, so Monday from noon on is Monday's.

**The value** (nightly). The 20% trimmed mean of the values in the last `recent` nights up to `now`:
the night's middle, with the highest and lowest fifth set aside, so one wild night can't move it.

**The change** (weekly, D99's week). It is judged on the week that ended before the latest Monday noon,
Monday to Sunday by night, and held until the next. The first `baseline` values are where the person
started; the judged week's values after them (at least `min_recent`) are where they are.
- d is the difference of the two trimmed means.
- The spread is the person's own night-to-night noise, pooled over every week judged so far (and the
  first nights): each night's distance from its own week's trimmed mean, winsorized at the same 20%, as
  a winsorized standard deviation. Within-week, so a level that moves from week to week is the
  person's level, not noise; pooled, so a calm or a wild week doesn't swing it. A winsorized spread
  rather than a bare MAD because a trimmed mean's error depends on the shoulders of the nights, which
  a MAD doesn't see (the study shows a MAD-based error lets heavy-tailed people through).
- se = spread · c · sqrt(1/n_first + 1/n_week), with c = 1/(1 − 2·trim), Tukey and McLaughlin's.
- **The test is spent over the looks.** The k-th weekly look needs |d| ≥ z_k·se with
  z_k = Φ⁻¹(1 − α_k/2), α_k = miss · k^−power, and |d| ≥ the floor. A change already said the week before,
  the same way, is kept while it clears the floor and the first look's z: being told again what was
  already said can't add a false first claim, and it stops the line flip-flopping.
How steady (`spread_measure`) is the same on each night's distance from its window's median: the first
`steady` values against the `steady` nights ending with the judged week (at least `min_steady_recent`).
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Sequence

from dusk_model.insights import normal_quantile

TOWARD, AWAY, STEADY = "toward", "away", "steady"


@dataclass(frozen=True)
class Rule:
    """`TollConfig.trends`."""

    baseline: int = 7
    recent: int = 7
    min_show: int = 3
    min_recent: int = 5
    floor_minutes: float = 15.0
    floor_reaches: float = 0.5
    floor_nights: float = 2.0
    steady: int = 14
    min_steady: int = 7
    min_steady_recent: int = 10
    floor_steady: float = 10.0
    trim: float = 0.2
    miss: float = 0.05
    power: float = 2.0
    spread: str = "winsor"  # the study's alternatives: "mad", "sd"

    def z(self, look: int) -> float:
        return normal_quantile(1.0 - self.miss * look**-self.power / 2.0)


Series = Sequence[tuple[int, float]]


def trimmed(values: Sequence[float], trim: float) -> float:
    v = sorted(values)
    if not v:
        return 0.0
    g = cut(len(v), trim)
    kept = v[g : len(v) - g]
    return sum(kept) / len(kept)


def winsorized(values: Sequence[float], trim: float) -> list[float]:
    v = sorted(values)
    g = cut(len(v), trim)
    if g == 0 or len(v) <= 2 * g:
        return list(values)
    low, high = v[g], v[len(v) - 1 - g]
    return [min(max(x, low), high) for x in values]


def median(values: Sequence[float]) -> float:
    v = sorted(values)
    if not v:
        return 0.0
    mid = len(v) // 2
    return v[mid] if len(v) % 2 else (v[mid - 1] + v[mid]) / 2


def pooled_spread(blocks: Sequence[Sequence[float]], rule: Rule) -> float:
    """The night-to-night noise of several weeks, each about its own trimmed mean."""
    residuals: list[float] = []
    for block in blocks:
        if len(block) < 2:
            continue
        if rule.spread == "winsor":
            w = winsorized(block, rule.trim)
            m = sum(w) / len(w)
            residuals += [x - m for x in w]
        else:
            m = trimmed(block, rule.trim) if rule.spread == "mad" else sum(block) / len(block)
            residuals += [x - m for x in block]
    if not residuals:
        return 0.0
    if rule.spread == "mad":
        mad = 1.4826 * median([abs(r) for r in residuals])
        # Counts tie at their middle (most nights no reaches): the mean distance stands in.
        return mad if mad > 0 else math.sqrt(math.pi / 2) * sum(abs(r) for r in residuals) / len(residuals)
    count = len(residuals) - sum(1 for b in blocks if len(b) >= 2)
    return math.sqrt(sum(r * r for r in residuals) / max(1, count))


def cut(n: int, trim: float) -> int:
    """How many values a trimmed mean sets aside at each end."""
    return int(math.floor(trim * n + 1e-9))


def standard_error(spread: float, a: int, b: int, rule: Rule) -> float:
    """Of a difference of two trimmed means. With a winsorized spread each mean's error is
    spread / ((1 − 2g/n)·√n) (Tukey and McLaughlin); a MAD or a standard deviation is used bare."""

    def share(n: int) -> float:
        kept = n - 2 * cut(n, rule.trim) if rule.spread == "winsor" else n
        return n / (kept * kept)

    return spread * math.sqrt(share(a) + share(b))


def way(d: float, lower_is_better: bool) -> str:
    return TOWARD if (d < 0) == lower_is_better else AWAY


@dataclass
class Look:
    """One week's judgement."""

    monday: int
    look: int
    d: float
    se: float
    z: float
    way: str


def judged_monday(now: int) -> int:
    """The Monday that starts the week holding `now`: its week before is the one judged."""
    return now - now % 7


def looks(
    series: Series, now: int, floor: float, lower_is_better: bool, rule: Rule, *, center=None, window=None
) -> tuple[list[Look], list[float]]:
    """Every weekly judgement up to the one in force at `now`, oldest first, and the first values.

    `center` maps a block's values to what is compared (the identity for a level; the distances from
    the median for How steady); `window` is how many nights each look reads back from its Monday."""
    center = center or (lambda block: list(block))
    window = window or 7
    size = rule.baseline if window == 7 else rule.steady
    least = rule.min_recent if window == 7 else rule.min_steady_recent
    ordered = sorted(series)
    first = ordered[:size]
    if len(first) < size:
        return [], []
    end = first[-1][0]
    then = center([v for _, v in first])
    blocks: list[list[float]] = [then]
    out: list[Look] = []
    held: str | None = None
    monday = judged_monday(end) + 7
    last = judged_monday(now)
    k = 0
    while monday <= last:
        later = [v for n, v in ordered if monday - window <= n < monday and n > end]
        if len(later) >= least:
            after = center(later)
            k += 1
            # Weeks don't overlap, so every one judged adds to the person's noise; How steady's
            # windows do, so it reads its own two.
            if window == 7:
                blocks.append(after)
            pool = blocks if window == 7 else [then, after]
            se = standard_error(pooled_spread(pool, rule), len(then), len(after), rule)
            d = trimmed(after, rule.trim) - trimmed(then, rule.trim)
            z = rule.z(k)
            clears = abs(d) >= floor
            w = way(d, lower_is_better)
            if clears and held == w and abs(d) >= rule.z(1) * se:
                result = w
            elif clears and abs(d) >= z * se:
                result = w
            else:
                result = STEADY
            held = result if result != STEADY else None
            out.append(Look(monday, k, d, se, z, result))
        monday += 7
    return out, then


def in_force(found: list[Look], now: int) -> Look | None:
    """The judgement the screen shows: the latest week's, if that week was judged."""
    return found[-1] if found and found[-1].monday == judged_monday(now) else None


def recent(series: Series, now: int, nights: int) -> list[float]:
    return [v for n, v in series if now - nights < n <= now]


def level_measure(series: Series, now: int, floor: float, lower_is_better: bool, rule: Rule = Rule()) -> dict | None:
    """Asleep by, Time asleep, Phone down by, Reaching: the value, the first level and the change."""
    values = recent(series, now, rule.recent)
    if len(values) < rule.min_show:
        return None
    found, then = looks(series, now, floor, lower_is_better, rule)
    look = in_force(found, now)
    return {
        "value": trimmed(values, rule.trim),
        "nights": len(values),
        "first": trimmed(then, rule.trim) if look else None,
        "change": None if look is None else {"way": look.way, "d": look.d, "look": look.look, "first": rule.baseline},
    }


def distances(block: Sequence[float]) -> list[float]:
    m = median(block)
    return [abs(x - m) for x in block]


def spread_measure(series: Series, now: int, rule: Rule = Rule()) -> dict | None:
    """How steady: the trimmed mean distance from the middle night, the last `steady` nights."""
    values = recent(series, now, rule.steady)
    if len(values) < rule.min_steady:
        return None
    found, then = looks(series, now, rule.floor_steady, True, rule, center=distances, window=rule.steady)
    look = in_force(found, now)
    first = [v for _, v in sorted(series)[: rule.steady]]
    return {
        "value": trimmed(distances(values), rule.trim),
        "middle": median(values),
        "nights": len(values),
        "first": trimmed(then, rule.trim) if look else None,
        "first_middle": median(first) if look else None,
        "change": None if look is None else {"way": look.way, "d": look.d, "look": look.look, "first": rule.steady},
    }


def locked_measure(ran: Series, now: int, rule: Rule = Rule()) -> dict | None:
    """Nights locked of the last seven, against the first seven: counts, so only the floor applies.
    Judged on the same week as the others."""
    values = recent(ran, now, rule.recent)
    if len(values) < rule.min_show:
        return None
    ordered = sorted(ran)
    first = ordered[: rule.baseline]
    change = None
    if len(first) == rule.baseline:
        monday = judged_monday(now)
        later = [v for n, v in ordered if monday - 7 <= n < monday and n > first[-1][0]]
        if len(later) >= rule.min_recent:
            d = (sum(later) / len(later) - sum(v for _, v in first) / len(first)) * rule.baseline
            w = STEADY if abs(d) < rule.floor_nights else TOWARD if d > 0 else AWAY
            change = {"way": w, "d": d, "first": rule.baseline}
    return {"value": sum(values), "nights": len(values), "change": change}
