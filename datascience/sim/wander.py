"""Background change in a person's usual time to fall asleep, laid over a scenario's nights (#154).

A twist is named after the scenario, as in "null+l45-r0.6". Each adds to the world's nightly noise:
- **drift**: `dampening.md`'s random walk, 2 minutes a night (`sim.dampen_sweep`).
- **wander**: the first year-long wander (`longrun.md`): an AR(1) with sd 15 minutes and a memory of
  about 4 weeks. Kept for comparison.
- **A grid of profiles** (`sim.profiles`), invented to bracket how much people's usual time moves.
  The usual time is set week by week, Monday to Sunday, so a week's level lines up with a held
  week's start: the hard case.
"""

from __future__ import annotations

import numpy as np

from .dampen_sweep import make_world as drifted_world
from .profiles import PROFILES
from .run import World

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
        if profile.tail:
            rng = np.random.default_rng([seed, 10])
            far = rng.random(w.noise.shape) < profile.tail
            w.noise = np.where(far, rng.normal(size=w.noise.shape) * profile.tail_sd, w.noise)
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
    rho = profile.memory
    level = rng.normal(0.0, profile.level, people)
    steps = rng.normal(0.0, profile.level * np.sqrt(1 - rho * rho), (people, weeks))
    out = np.zeros((people, weeks))
    for k in range(weeks):
        if k:
            level = rho * level + steps[:, k]
        out[:, k] = level
    return np.repeat(out, 7, axis=1)[:, :nights]
