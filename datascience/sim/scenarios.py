"""Synthetic people: each one's true four numbers, schedule and imperfections.

Everything here is an assumption to vary, not a fact (model spec, section 6.1). The truth is set apart
from the artifact's base on purpose, so the model has to find its way from a wrong starting point.

True onset, in minutes from planned bedtime, for start offset a (minutes):
    c0 + h(a) + c2·weekend + c3·late + day-to-day noise + outlier
with h(a) = c1·a/30, plus q·((a/30)² − 2/3) in the non-linear scenario. A positive c1 means an earlier
start brings sleep sooner. Health reports the onset with its own error.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

SCENARIOS = ["same", "differ", "nonresponders", "worse", "nonlinear", "null"]

# The population the people are drawn from (not the model's base).
POP_MEAN = np.array([20.0, 8.0, 30.0, 25.0])
POP_SD = np.array([20.0, 15.0, 20.0, 15.0])


@dataclass
class People:
    truth: np.ndarray  # (P, 4) c0..c3
    curvature: np.ndarray  # (P,) q, zero unless non-linear
    natural_sd: np.ndarray  # (P,) night-to-night variation of the real onset
    measure_sd: np.ndarray  # (P,) Health's error on the onset
    away_rate: np.ndarray  # (P,)
    while_using: np.ndarray  # (P,) bool: location never reports arrivals
    allowed: np.ndarray  # (P, 3) bool over actions (-30, 0, 30)
    fade: bool  # the start's effect halves every 3 weeks

    @property
    def count(self) -> int:
        return len(self.truth)


def draw(scenario: str, count: int, rng: np.random.Generator, fade: bool = False) -> People:
    if scenario not in SCENARIOS:
        raise ValueError(f"unknown scenario {scenario}")
    truth = POP_MEAN + rng.normal(size=(count, 4)) * POP_SD
    curvature = np.zeros(count)
    effect = truth[:, 1]
    if scenario == "same":
        truth[:] = POP_MEAN
        effect = np.full(count, 3.0)
    elif scenario == "differ":
        effect = rng.normal(8.0, 15.0, count)
    elif scenario == "nonresponders":
        responds = rng.random(count) < 0.4
        effect = np.where(responds, rng.normal(12.0, 5.0, count), 0.0)
    elif scenario == "worse":
        hurt = rng.random(count) < 0.25
        effect = np.where(hurt, rng.normal(-10.0, 4.0, count), rng.normal(10.0, 5.0, count))
    elif scenario == "nonlinear":
        effect = rng.normal(8.0, 10.0, count)
        curvature = rng.normal(0.0, 8.0, count)
    elif scenario == "null":
        effect = np.zeros(count)
    truth[:, 1] = effect

    allowed = np.ones((count, 3), dtype=bool)
    limit = rng.random(count)
    allowed[limit < 0.2, 2] = False  # "never later than my plan"
    allowed[(limit >= 0.2) & (limit < 0.3), 0] = False  # "never earlier"
    return People(
        truth=truth,
        curvature=curvature,
        natural_sd=rng.uniform(15.0, 25.0, count),
        measure_sd=rng.uniform(15.0, 30.0, count),
        away_rate=rng.uniform(0.10, 0.20, count),
        while_using=rng.random(count) < 0.10,
        allowed=allowed,
        fade=fade,
    )


def response(people: People, offset: np.ndarray, night: int) -> np.ndarray:
    """h(a) for each person tonight."""
    x = offset / 30.0
    slope = people.truth[:, 1] * (0.5 ** (night / 21.0) if people.fade else 1.0)
    return slope * x + people.curvature * (x * x - 2.0 / 3.0)


def true_effect(people: People, night: int) -> np.ndarray:
    """The number the insight estimates: the average slope per 30 minutes, tonight."""
    return people.truth[:, 1] * (0.5 ** (night / 21.0) if people.fade else 1.0)
