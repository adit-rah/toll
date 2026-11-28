"""Background change in a person's usual time to fall asleep, laid over a scenario's nights (#154).

A twist is named after the scenario, as in "null+wide". Each adds to the world's nightly noise:
- **drift**: `dampening.md`'s random walk, 2 minutes a night (`sim.dampen_sweep`).
- **wander**: the first year-long wander (`longrun.md`): an AR(1) with sd 15 minutes and a memory of
  about 4 weeks. Kept for comparison.
- **wide** and **slow**: two profiles at the two ends of how much real people's usual time moves,
  checked against a real Health export (n=1, private). The usual time is set week by week, Monday to
  Sunday, by an AR(1) across weeks, so a week's level lines up with a held week's start: the hard case.
  - wide: large week-to-week swings with a short memory, and heavy-tailed nights: in place of the
    simulator's night-to-night noise, most nights are normal around the week's level and 30% come from
    a far wider normal, so about one night in six lands more than 90 minutes from its week's median.
  - slow: smaller swings with a long memory (months), and the simulator's own nightly noise.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .dampen_sweep import make_world as drifted_world
from .run import World


@dataclass(frozen=True)
class Profile:
    """A weekly AR(1) level (sd `week_sd`, correlation `week_rho` from one week to the next), and
    optionally nightly noise of sd `night_sd`, a share `wide_share` of nights drawn with sd `wide_sd`."""

    week_sd: float
    week_rho: float
    night_sd: float = 0.0
    wide_share: float = 0.0
    wide_sd: float = 0.0


PROFILES = {
    "wide": Profile(week_sd=60.0, week_rho=0.35, night_sd=25.0, wide_share=0.3, wide_sd=200.0),
    "slow": Profile(week_sd=30.0, week_rho=0.9),
}
WANDER_SD = 15.0
WANDER_DAYS = 28.0
TWISTS = ("drift", "fade", "wander", *PROFILES)


def make_world(scenario: str, people: int, seed: int, nights: int) -> World:
    name, _, twist = scenario.partition("+")
    if twist in ("", "drift", "fade"):
        return drifted_world(scenario, people, seed, nights=nights)
    if twist not in TWISTS:
        raise ValueError(f"unknown twist {twist}")
    w = drifted_world(name, people, seed, nights=nights)
    if twist == "wander":
        w.noise = w.noise + nightly_wander(people, nights, seed)
    else:
        profile = PROFILES[twist]
        if profile.night_sd:
            rng = np.random.default_rng([seed, 10])
            wide = rng.random(w.noise.shape) < profile.wide_share
            sd = np.where(wide, profile.wide_sd, profile.night_sd)
            w.noise = rng.normal(size=w.noise.shape) * sd
        w.noise = w.noise + weekly_level(profile, people, nights, seed)
    return w


def nightly_wander(people: int, nights: int, seed: int) -> np.ndarray:
    """`longrun.md`'s wander: an AR(1) night to night, sd 15, correlation e^(−1/28)."""
    rho = float(np.exp(-1.0 / WANDER_DAYS))
    steps = np.random.default_rng([seed, 8]).normal(0.0, WANDER_SD * np.sqrt(1 - rho * rho), (people, nights))
    level = np.random.default_rng([seed, 9]).normal(0.0, WANDER_SD, people)
    out = np.zeros((people, nights))
    for t in range(nights):
        if t:
            level = rho * level + steps[:, t]
        out[:, t] = level
    return out


def weekly_level(profile: Profile, people: int, nights: int, seed: int) -> np.ndarray:
    """A level per calendar week (night 0 is a Monday), stationary from the first week."""
    weeks = -(-nights // 7)
    rng = np.random.default_rng([seed, 11])
    rho = profile.week_rho
    level = rng.normal(0.0, profile.week_sd, people)
    steps = rng.normal(0.0, profile.week_sd * np.sqrt(1 - rho * rho), (people, weeks))
    out = np.zeros((people, weeks))
    for k in range(weeks):
        if k:
            level = rho * level + steps[:, k]
        out[:, k] = level
    return np.repeat(out, 7, axis=1)[:, :nights]
