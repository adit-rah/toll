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
  When the first nights' own spread is more than `first_ratio` times the weeks' since, each side
  takes its own (Yuen's test, Welch's degrees of freedom): a person who calmed down would otherwise
  have the first nights' level taken as surer than it is (#173).
- **The test is spent over the looks.** The k-th weekly look needs |d| ≥ z_k·se with
  z_k = Φ⁻¹(1 − α_k/2), α_k = miss · k^−power, and |d| ≥ the floor. A change already said the week before,
  the same way, is kept while it clears the floor and the first look's z: being told again what was
  already said can't add a false first claim, and it stops the line flip-flopping.
How steady (`spread_measure`) is the same on each night's distance from the middle of the nights
within three days of it (#173): the first `steady` values against the `steady` nights ending with the
judged week (at least `min_steady_recent`). A local middle, so a usual time that moves isn't read as
unsteady nights; that's the level's line to say.
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
    miss: float = 0.02
    power: float = 2.0
    spread: str = "winsor"  # the study's alternative: "mad"
    # How steady's middle for each night (#173): "local", the nights within `around` days of it in
    # the same window; the study's alternatives "window" (D108's) and "halves".
    centre: str = "local"
    around: int = 3
    # The first nights' own noise stands for their error once it is more than this times the
    # weeks' since (#173); 0 never.
    first_ratio: float = 1.5

    def z(self, look: int, df: int) -> float:
        """The k-th look's test: Student's t with the pooled nights' degrees of freedom, so the
        first looks, with two weeks of noise to go on, aren't taken as surer than they are."""
        return t_quantile(1.0 - self.miss * look**-self.power / 2.0, df)


def t_quantile(p: float, df: int) -> float:
    """Student's t from the normal quantile by the Cornish–Fisher expansion (Hill, 1970): within
    0.1% of the exact value from 8 degrees of freedom, the fewest a look has."""
    z = normal_quantile(p)
    n = float(max(df, 1))
    z2 = z * z
    return z * (
        1
        + (z2 + 1) / (4 * n)
        + ((5 * z2 + 16) * z2 + 3) / (96 * n * n)
        + (((3 * z2 + 19) * z2 + 17) * z2 - 15) / (384 * n**3)
        + ((((79 * z2 + 776) * z2 + 1482) * z2 - 1920) * z2 - 945) / (92160 * n**4)
    )


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
            m = trimmed(block, rule.trim)
            residuals += [x - m for x in block]
    if not residuals:
        return 0.0
    if rule.spread == "mad":
        mad = 1.4826 * median([abs(r) for r in residuals])
        # Counts tie at their middle (most nights no reaches): the mean distance stands in.
        return mad if mad > 0 else math.sqrt(math.pi / 2) * sum(abs(r) for r in residuals) / len(residuals)
    count = len(residuals) - sum(1 for b in blocks if len(b) >= 2)
    return math.sqrt(sum(r * r for r in residuals) / max(1, count))


def degrees(blocks: Sequence[Sequence[float]], trim: float) -> int:
    """The pooled spread's degrees of freedom: each block's kept nights, less one (Yuen's)."""
    return max(1, sum(len(b) - 2 * cut(len(b), trim) - 1 for b in blocks if len(b) >= 2))


def cut(n: int, trim: float) -> int:
    """How many values a trimmed mean sets aside at each end."""
    return int(math.floor(trim * n + 1e-9))


def standard_error(spread: float, a: int, b: int, rule: Rule) -> float:
    """Of a difference of two trimmed means. With a winsorized spread each mean's error is
    spread / ((1 − 2g/n)·√n) (Tukey and McLaughlin); a MAD or a standard deviation is used bare."""

    return spread * math.sqrt(share(a, rule) + share(b, rule))


def share(n: int, rule: Rule) -> float:
    """A mean's variance over n nights, per unit of spread."""
    kept = n - 2 * cut(n, rule.trim) if rule.spread == "winsor" else n
    return n / (kept * kept)


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
    df: int
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
    center = center or (lambda pairs: [v for _, v in pairs])
    window = window or 7
    size = rule.baseline if window == 7 else rule.steady
    least = rule.min_recent if window == 7 else rule.min_steady_recent
    ordered = sorted(series)
    first = ordered[:size]
    if len(first) < size:
        return [], []
    end = first[-1][0]
    then = center(first)
    blocks: list[list[float]] = [then]
    out: list[Look] = []
    held: str | None = None
    monday = judged_monday(end) + 7
    last = judged_monday(now)
    k = 0
    while monday <= last:
        later = [(n, v) for n, v in ordered if monday - window <= n < monday and n > end]
        if len(later) >= least:
            after = center(later)
            k += 1
            # Weeks don't overlap, so every one judged adds to the person's noise; How steady's
            # windows do, so it reads its own two.
            if window == 7:
                blocks.append(after)
            pool = blocks if window == 7 else [then, after]
            se, df = error(pool, rule) if window == 7 else error(pool, rule, guard=False)
            d = trimmed(after, rule.trim) - trimmed(then, rule.trim)
            z = rule.z(k, df)
            clears = abs(d) >= floor
            w = way(d, lower_is_better)
            if clears and held == w and abs(d) >= rule.z(1, df) * se:
                result = w
            elif clears and abs(d) >= z * se:
                result = w
            else:
                result = STEADY
            held = result if result != STEADY else None
            out.append(Look(monday, k, d, se, z, df, result))
        monday += 7
    return out, then


def error(pool: list[list[float]], rule: Rule, guard: bool = True) -> tuple[float, int]:
    """The difference's error and degrees of freedom: the pooled noise, unless the first nights
    were clearly noisier than every week since (a person who calmed down). Pooled, the calm weeks
    would then hide how unsure the first nights' level is; so each side takes its own noise, with
    Welch's degrees of freedom (Yuen's test, #173)."""
    then, after = pool[0], pool[-1]
    pooled = standard_error(pooled_spread(pool, rule), len(then), len(after), rule), degrees(pool, rule.trim)
    if not guard or rule.first_ratio <= 0 or len(pool) < 2:
        return pooled
    since = pool[1:]
    first, later = pooled_spread([then], rule), pooled_spread(since, rule)
    if first <= rule.first_ratio * later:
        return pooled
    a = share(len(then), rule) * first * first
    b = share(len(after), rule) * later * later
    df = (a + b) ** 2 / (a * a / degrees([then], rule.trim) + b * b / degrees(since, rule.trim))
    return math.sqrt(a + b), max(1, math.floor(df))


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


def centred(pairs: Sequence[tuple[int, float]], how: str, around: int = 3) -> list[float]:
    """How steady's distances for a window of (night, value), oldest first. "local" (#173): each
    night's distance from the middle of the nights within `around` days of it, in the same window,
    so a usual time that moved between weeks, or once inside the first nights, isn't read as
    unsteady nights."""
    values = [v for _, v in pairs]
    if how == "window" or not pairs:
        return distances(values)
    if how == "halves":
        end = pairs[-1][0]
        late = [v for n, v in pairs if n > end - 7]
        early = [v for n, v in pairs if n <= end - 7]
        return distances(early) + distances(late)
    return [abs(v - median([w for m, w in pairs if abs(m - n) <= around])) for n, v in pairs]


def spread_measure(series: Series, now: int, rule: Rule = Rule()) -> dict | None:
    """How steady: the trimmed mean distance from the middle night, the last `steady` nights."""
    values = recent(series, now, rule.steady)
    if len(values) < rule.min_steady:
        return None
    found, then = looks(
        series, now, rule.floor_steady, True, rule, center=lambda w: centred(w, rule.centre, rule.around), window=rule.steady
    )
    look = in_force(found, now)
    first = [v for _, v in sorted(series)[: rule.steady]]
    window = sorted((n, v) for n, v in series if now - rule.steady < n <= now)
    return {
        "value": trimmed(centred(window, rule.centre, rule.around), rule.trim),
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
