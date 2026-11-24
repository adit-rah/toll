"""The growing gap's weekly rule (decisions D76) and the tolerance assumed to drive it.

The rule is the founder's: the lock starts a gap before bed, 15 minutes at first, and each Monday the
last week is judged. A smooth week (the lock ran on 4 nights or more, at most 1 pause started inside the
gap, Screen Time never off) grows it by 15, up to 60. A hard week (2 or more pauses inside the gap) eases
it by 15. Screen Time switched off eases it by 15 and stops growth for 2 weeks. After an ease, two smooth
weeks in a row are needed to grow again. Anything else holds.

Everything in `Tolerance` is an assumption, not a fact: nobody has measured how people meet a lock that
starts before bed. Each person has a comfort, the minutes before bed they can go without the apps. Within
it, a pause inside the gap is rare; past it, the nightly chance rises toward `max_rate`. A hard week
sometimes ends with Screen Time switched off, and some of those people leave it off for good.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass(frozen=True)
class GapRule:
    grows: bool = True  # False: a fixed gap that never changes
    start: int = 15
    step: int = 15
    cap: int = 60
    smooth_min_nights: int = 4
    hard_pauses: int = 2
    off_freeze_weeks: int = 2


@dataclass(frozen=True)
class Tolerance:
    comfort_mean: float = 45.0  # minutes before bed without the apps that a person is fine with
    comfort_sd: float = 20.0
    base_rate: float = 0.03  # nightly chance of a pause inside the gap within comfort
    max_rate: float = 0.5  # the nightly chance far past comfort
    scale: float = 20.0  # minutes past comfort that close about 63% of the way to max_rate
    off_per_hard_week: float = 0.2  # chance a hard week ends with Screen Time switched off
    quit_share: float = 0.5  # of those, the share who leave it off for good
    pauses_per_week: int = 3  # D67


def pause_chance(lead: np.ndarray, comfort: np.ndarray, tol: Tolerance) -> np.ndarray:
    """Tonight's chance of a pause started inside the gap, for a lock `lead` minutes before bed."""
    past = np.maximum(lead - comfort, 0.0)
    rate = tol.base_rate + (tol.max_rate - tol.base_rate) * (1.0 - np.exp(-past / tol.scale))
    return np.where(lead > 0, rate, 0.0)


def dose(gap: np.ndarray, kind: str) -> np.ndarray:
    """Minutes of earlier start the gap is worth. "saturating": past 30 minutes, each minute counts half."""
    if kind == "linear":
        return gap
    if kind == "saturating":
        return np.minimum(gap, 30.0) + 0.5 * np.maximum(gap - 30.0, 0.0)
    raise ValueError(f"unknown dose {kind}")


@dataclass
class Luck:
    """Each person's comfort and the uniforms behind their pauses and switch-offs, drawn once per seed so
    every variant meets the same people on the same nights."""

    comfort: np.ndarray  # (P,)
    pause_u: np.ndarray  # (P, nights)
    off_u: np.ndarray  # (P, weeks)
    quit_u: np.ndarray  # (P, weeks)


def luck(count: int, nights: int, seed: int, tol: Tolerance) -> Luck:
    gen = np.random.default_rng([seed, 76])
    weeks = nights // 7 + 1
    return Luck(
        comfort=np.maximum(tol.comfort_mean + tol.comfort_sd * gen.standard_normal(count), 0.0),
        pause_u=gen.random((count, nights)),
        off_u=gen.random((count, weeks)),
        quit_u=gen.random((count, weeks)),
    )


@dataclass
class GapState:
    gap: np.ndarray  # (P,) minutes
    streak: np.ndarray  # smooth weeks in a row
    need_two: np.ndarray  # an ease since the last growth
    frozen_until: np.ndarray  # no growth at Monday judgments up to this one (Screen Time was off)
    stopped: np.ndarray  # growth stopped by personal timing (D76)
    eased: np.ndarray  # eased at least once

    @classmethod
    def start(cls, count: int, rule: GapRule) -> "GapState":
        return cls(
            gap=np.full(count, float(rule.start)),
            streak=np.zeros(count, dtype=np.int64),
            need_two=np.zeros(count, dtype=bool),
            frozen_until=np.full(count, -1, dtype=np.int64),
            stopped=np.zeros(count, dtype=bool),
            eased=np.zeros(count, dtype=bool),
        )

    def settled(self, rule: GapRule) -> np.ndarray:
        """Done growing: at the cap, or it has met the person's edge and eased once."""
        return (self.gap >= rule.cap) | self.eased


@dataclass
class Week:
    smooth: np.ndarray
    hard: np.ndarray
    off: np.ndarray
    grew: np.ndarray
    eased: np.ndarray


def judge(s: GapState, rule: GapRule, monday: int, lock_nights: np.ndarray, pauses: np.ndarray, off: np.ndarray) -> Week:
    """Monday `monday`'s judgment of the week before it; changes `s` in place."""
    hard = pauses >= rule.hard_pauses
    smooth = (lock_nights >= rule.smooth_min_nights) & ~hard & ~off
    none = np.zeros_like(hard)
    if not rule.grows:
        return Week(smooth, hard, off, none, none)
    ease = hard | off
    s.frozen_until = np.where(off, monday + rule.off_freeze_weeks, s.frozen_until)
    s.streak = np.where(smooth, s.streak + 1, 0)
    needed = np.where(s.need_two, 2, 1)
    grow = smooth & (s.streak >= needed) & (monday > s.frozen_until) & ~s.stopped & (s.gap < rule.cap)
    s.gap = np.clip(s.gap + rule.step * grow - rule.step * ease, 0.0, float(rule.cap))
    s.streak = np.where(grow, 0, s.streak)
    s.need_two = (s.need_two & ~grow) | ease
    s.eased = s.eased | ease
    return Week(smooth, hard, off, grow, ease)
