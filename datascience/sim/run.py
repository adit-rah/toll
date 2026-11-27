"""Runs synthetic people through 8 weeks of nights (or as many as the world has) under a policy.

The world's randomness (away nights, missing Health data, noise, outliers, late arrivals) is drawn once
per seed, so the model's policy and the fixed plan are compared on identical nights. The policy is the
artifact's (`dusk_model.timing`): v0's nightly draw, or v1's held, settling week. Its draws come from
each person's SplitMix64 stream, as on the phone.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

import numpy as np

from dusk_model.artifact import Params
from dusk_model.insights import shown
from dusk_model.model import prior_state, update
from dusk_model.rng import SplitMix64Batch
from dusk_model.timing import Holds, choose, day_number

from .scenarios import People, draw, response, true_effect

WEEKS = 8
NIGHTS = WEEKS * 7
ACTIONS = np.array([-30, 0, 30])
CHUNK = 500
FIRST_NIGHT = date(2026, 1, 5)  # a Monday, as in sim.records


@dataclass
class World:
    """Everything about the nights that the policy cannot change. Arrays are (P, nights)."""

    people: People
    weekend: np.ndarray
    away: np.ndarray
    missing: np.ndarray
    tz_changed: np.ndarray
    late: np.ndarray
    noise: np.ndarray
    measure: np.ndarray
    outlier: np.ndarray

    @property
    def late_seen(self) -> np.ndarray:
        """Arrivals are unknown on While Using location, so the model sees no late nights."""
        return self.late & ~self.people.while_using[:, None]


def world(scenario: str, count: int, seed: int, fade: bool = False, nights: int = NIGHTS) -> World:
    rng = np.random.default_rng(seed)
    people = draw(scenario, count, rng, fade)
    shape = (count, nights)
    # Night 0 is a Monday; Friday and Saturday nights are the weekend.
    weekend = np.broadcast_to(np.isin(np.arange(nights) % 7, [4, 5]), shape).copy()
    late_rate = np.where(weekend, 0.25, 0.15)
    outlier = rng.random(shape) < 0.03
    return World(
        people=people,
        weekend=weekend,
        away=rng.random(shape) < people.away_rate[:, None],
        missing=rng.random(shape) < 0.15,
        tz_changed=rng.random(shape) < 0.01,
        late=rng.random(shape) < late_rate,
        noise=rng.normal(size=shape) * people.natural_sd[:, None],
        measure=rng.normal(size=shape) * people.measure_sd[:, None],
        outlier=np.where(outlier, rng.uniform(60.0, 150.0, shape), 0.0),
    )


@dataclass
class Run:
    offset: np.ndarray  # (P, nights); 0 on away nights
    prob: np.ndarray
    true_onset: np.ndarray  # minutes from planned bedtime, before Health's error
    measured: np.ndarray  # what Health reports
    home: np.ndarray  # a block ran
    usable: np.ndarray
    shown: np.ndarray  # insight visible after each night
    estimate: np.ndarray  # (P, nights) the start effect after each night
    low: np.ndarray
    high: np.ndarray
    truth: np.ndarray  # (P, nights) the true start effect that night
    held: np.ndarray  # (P, nights) the policy's start for the night, also on nights the block didn't run
    held_prob: np.ndarray  # its logged chance
    settled: np.ndarray  # (P, nights) the hold was chosen settled
    hold_start: np.ndarray  # (P, nights) the hold's first night, as nights since night 0


def true_onset(w: World, offset: np.ndarray, night: int) -> np.ndarray:
    c = w.people.truth
    return (
        c[:, 0]
        + response(w.people, offset, night)
        + c[:, 2] * w.weekend[:, night]
        + c[:, 3] * w.late[:, night]
        + w.noise[:, night]
        + w.outlier[:, night]
    )


def run(w: World, params: Params, policy: str, seed: int = 0) -> Run:
    count, nights = w.away.shape
    state = prior_state(params, count)
    rng = SplitMix64Batch(np.arange(count, dtype=np.uint64) + np.uint64(seed * 1_000_003))
    holds = Holds.none(count)
    first = day_number(FIRST_NIGHT)
    keys = ("offset", "prob", "true_onset", "measured", "estimate", "low", "high", "truth", "held", "held_prob", "hold_start")
    out = {k: np.zeros((count, nights)) for k in keys}
    flags = {k: np.zeros((count, nights), dtype=bool) for k in ("home", "usable", "shown", "settled")}
    for t in range(nights):
        home = ~w.away[:, t]
        if policy == "thompson":
            for lo in range(0, count, CHUNK):
                part = slice(lo, lo + CHUNK)
                sub = state.rows(part)
                sub_holds = Holds(*(getattr(holds, f)[part] for f in ("period", "start", "offset", "prob", "settled")))
                sub_rng = SplitMix64Batch(rng.state[part])
                got = choose(
                    sub, sub_holds, first + t, w.weekend[part, t], w.late_seen[part, t], w.people.allowed[part], sub_rng, params
                )
                for f in ("period", "start", "offset", "prob", "settled"):
                    getattr(holds, f)[part] = getattr(got, f)
                rng.state[part] = sub_rng.state
            held, held_prob = holds.offset.copy(), holds.prob.copy()
        else:
            held, held_prob = np.zeros(count), np.ones(count)
        offset = np.where(home, held, 0.0)
        prob = np.where(home, held_prob, 1.0) if params.hold_nights == 1 and not params.settles else held_prob
        onset = true_onset(w, offset, t)
        # Health reports whole seconds.
        measured = np.round((onset + w.measure[:, t]) * 60.0) / 60.0
        usable = home & ~w.missing[:, t] & ~w.tz_changed[:, t] & (np.abs(measured) <= params.max_onset_from_plan_min)
        phi = np.column_stack([np.ones(count), offset / 30.0, w.weekend[:, t], w.late_seen[:, t]]).astype(float)
        update(state, phi, measured, usable, params)
        ok, effect, low, high = shown(state, params)
        out["offset"][:, t], out["prob"][:, t], out["true_onset"][:, t] = offset, prob, onset
        out["measured"][:, t] = measured
        out["estimate"][:, t], out["low"][:, t], out["high"][:, t] = effect, low, high
        out["truth"][:, t] = true_effect(w.people, t)
        out["held"][:, t], out["held_prob"][:, t] = held, held_prob
        out["hold_start"][:, t] = holds.start - first if policy == "thompson" else t
        flags["home"][:, t], flags["usable"][:, t], flags["shown"][:, t] = home, usable, ok
        flags["settled"][:, t] = holds.settled if policy == "thompson" else False
    return Run(**out, **flags)
