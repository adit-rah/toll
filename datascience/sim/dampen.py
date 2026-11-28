"""Dampened start policies: smaller, rarer or smoother moves of tonight's block start (decisions D65).

An exploration harness, not a new artifact. The model, its update and the insight rule are v0's
(`dusk_model`); only how tonight's start is chosen changes. Every choice is logged with its exact
chance given the history, as the phone must for off-policy evaluation.

A policy, each night, for each person:
1. Thompson sampling over `grid` gives the chance each allowed start is best; `floor` keeps every
   allowed start at that chance or more, and `zero_floor` adds extra weight on the plan.
2. Settled people (an insight is shown, or the posterior is confident) use their best-supported start,
   except on a rare exploring night (`after_settle_per_week`), or a whole exploring dwell.
3. Unsettled people choose by step 1 every night (`explore_per_week` None, held for `dwell` nights),
   or only on k random nights of each week and keep the plan on the others.
4. `step` caps tonight's change from the last block night, so the start walks toward its target.

The sweep and the report's numbers come from `sim.dampen_sweep`.
"""

from __future__ import annotations

import dataclasses
from dataclasses import dataclass

import numpy as np

from dusk_model.artifact import Params
from dusk_model.insights import shown
from dusk_model.model import prior_state, update
from dusk_model.policy import features_for, win_probabilities

from .run import NIGHTS, World, true_onset
from .scenarios import response, true_effect


@dataclass(frozen=True)
class Policy:
    name: str
    grid: tuple[int, ...] = (-30, 0, 30)
    floor: float = 0.10
    zero_floor: float = 0.0
    explore_per_week: int | None = None
    explore: str = "thompson"  # or "uniform": any allowed start but the plan, equally
    dwell: int = 1
    step: int | None = None
    settle: str | None = None  # "insight" or "confident"
    settle_confidence: float = 0.9
    settle_max: int | None = None  # cap on the settled start's distance from the plan
    settle_plan_within: float | None = None  # settle on the plan once the 90% range is inside ±this
    after_settle_per_week: float = 0.5
    slope_prior_sd: float | None = None
    max_width: float | None = None  # the insight's widest shown range, per 30 minutes

    def params(self, base: Params, draws: int) -> Params:
        sd = base.prior_sd.copy()
        if self.slope_prior_sd is not None:
            sd[1] = self.slope_prior_sd
        width = base.max_width_min if self.max_width is None else self.max_width
        return dataclasses.replace(
            base, actions=self.grid, min_prob=self.floor, prob_draws=draws, prior_sd=sd, max_width_min=width
        )


class NumpyNormals:
    """The shape `win_probabilities` takes, from numpy: phone parity is not needed for exploration."""

    def __init__(self, gen: np.random.Generator, people: int):
        self.gen, self.people = gen, people

    def normal(self, n: int) -> np.ndarray:
        return self.gen.standard_normal((self.people, n))


def allowed_on(grid: np.ndarray, allowed3: np.ndarray) -> np.ndarray:
    """The simulator's limits are over (−30, 0, 30): "never later" and "never earlier" apply to every
    later or earlier start on any grid."""
    later_ok, earlier_ok = allowed3[:, 2], allowed3[:, 0]
    return np.where(grid[None, :] > 0, later_ok[:, None], np.where(grid[None, :] < 0, earlier_ok[:, None], True))


def floor_mix(p: np.ndarray, allowed: np.ndarray, floor: float, zero_floor: float, zero: int) -> np.ndarray:
    k = allowed.sum(axis=1).astype(float)[:, None]
    mixed = np.where(allowed, (1.0 - k * floor) * p + floor, 0.0)
    mixed = np.where(k == 1, allowed.astype(float), mixed)
    if zero_floor:
        mixed = (1.0 - zero_floor) * mixed
        mixed[:, zero] += zero_floor
    return mixed


def sample(dist: np.ndarray, u: np.ndarray) -> np.ndarray:
    """Index drawn from each row of `dist` with one uniform each."""
    cumulative = np.cumsum(dist, axis=1)
    pick = (u[:, None] >= cumulative).sum(axis=1)
    return np.minimum(pick, dist.shape[1] - 1)


@dataclass
class DampenRun:
    offset: np.ndarray  # (P, nights); 0 on away nights
    prob: np.ndarray  # exact chance of the start given the history; 1 when nothing was random
    gain: np.ndarray  # true onset minus the onset at plan, same night (below zero is earlier)
    home: np.ndarray
    change: np.ndarray  # |start − last block night's start|, home nights
    settled: np.ndarray
    settled_target: np.ndarray  # (P,) where each settled person's start sits after the last night
    shown: np.ndarray
    estimate: np.ndarray
    low: np.ndarray
    high: np.ndarray
    truth: np.ndarray


def run(w: World, base: Params, policy: Policy, seed: int, draws: int = 300) -> DampenRun:
    params = policy.params(base, draws)
    count = w.people.count
    grid = np.array(policy.grid, dtype=float)
    zero = int(np.flatnonzero(grid == 0)[0])
    allowed = allowed_on(grid, w.people.allowed)
    gen = np.random.default_rng([seed, 99])
    normals = NumpyNormals(gen, count)
    state = prior_state(params, count)

    current = np.zeros(count)  # the start held from the last choice (dwell)
    last_block = np.zeros(count)
    settled = np.zeros(count, dtype=bool)
    settled_target = np.zeros(count)
    exploring = np.zeros(count, dtype=bool)
    explore_night = np.ones((count, 7), dtype=bool)
    nonzero = allowed & (grid[None, :] != 0)
    uniform = np.where(nonzero.any(axis=1)[:, None], nonzero, allowed).astype(float)
    uniform /= uniform.sum(axis=1, keepdims=True)

    out = {k: np.zeros((count, NIGHTS)) for k in ("offset", "prob", "gain", "change", "estimate", "low", "high", "truth")}
    flags = {k: np.zeros((count, NIGHTS), dtype=bool) for k in ("home", "settled", "shown")}
    for t in range(NIGHTS):
        home = ~w.away[:, t]
        phi_k = features_for(params, w.weekend[:, t], w.late_seen[:, t])
        p = win_probabilities(state, phi_k, allowed, normals, params)
        thompson = floor_mix(p, allowed, policy.floor, policy.zero_floor, zero)
        explore_dist = uniform if policy.explore == "uniform" else thompson
        ok, effect, low, high = shown(state, params)

        if policy.settle is not None:
            reach = np.where(allowed, grid[None, :], np.nan)
            if policy.settle_max is not None:
                reach = np.where(np.abs(reach) <= policy.settle_max, reach, np.nan)
            # Linear in the start: the best-supported start is the farthest allowed one on the better side.
            best = np.where(effect > 0, np.nanmin(reach, axis=1), np.nanmax(reach, axis=1))
            if policy.settle == "insight":
                now = ok
            else:
                now = (p.max(axis=1) >= policy.settle_confidence) & (state.nights >= params.min_nights)
                best = np.where(now, grid[p.argmax(axis=1)], best)
            if policy.settle_max is not None:
                best = np.clip(best, -policy.settle_max, policy.settle_max)
            if policy.settle_plan_within is not None:
                plan_ok = (low > -policy.settle_plan_within) & (high < policy.settle_plan_within)
                plan_ok &= state.nights >= params.min_nights
                best = np.where(plan_ok & ~now, 0.0, best)
                now = now | plan_ok
            settled_target = np.where(now, best, settled_target)
            settled = settled | now

        if policy.explore_per_week is not None and t % 7 == 0:
            ranks = gen.random((count, 7)).argsort(axis=1).argsort(axis=1)
            explore_night = ranks < policy.explore_per_week
        u_choice = gen.uniform(size=count)
        u_explore = gen.uniform(size=count)
        drawn = grid[sample(explore_dist, u_choice)]

        # What each person wants tonight, and the chance of each target given the history (P, K).
        if policy.explore_per_week is None:
            decide = np.full(count, t % policy.dwell == 0)
            target = np.where(decide, drawn, current)
            target_dist = np.where(decide[:, None], explore_dist, grid[None, :] == current[:, None])
        else:
            chosen = explore_night[:, t % 7]
            target = np.where(chosen, drawn, 0.0)
            target_dist = np.where(chosen[:, None], explore_dist, (grid == 0)[None, :])
        # Settled people explore on a share of nights; with a dwell, for the whole dwell.
        rate = policy.after_settle_per_week / 7.0
        if policy.explore_per_week is None and t % policy.dwell != 0:
            explore_target, explore_now = current, exploring.astype(float)
            explore_now_dist = (grid[None, :] == current[:, None]).astype(float)
        else:
            exploring = u_explore < rate
            explore_target, explore_now, explore_now_dist = drawn, np.full(count, rate), explore_dist
        target = np.where(settled, np.where(exploring, explore_target, settled_target), target)
        held = (grid[None, :] == settled_target[:, None]).astype(float)
        mix = explore_now[:, None]
        target_dist = np.where(settled[:, None], mix * explore_now_dist + (1 - mix) * held, target_dist)
        current = target

        if policy.step is None:
            mapped = np.broadcast_to(grid[None, :], (count, len(grid)))
            offset = target
        else:
            mapped = last_block[:, None] + np.clip(grid[None, :] - last_block[:, None], -policy.step, policy.step)
            offset = last_block + np.clip(target - last_block, -policy.step, policy.step)
        prob = (target_dist * (mapped == offset[:, None])).sum(axis=1)
        offset = np.where(home, offset, 0.0)
        prob = np.where(home, prob, 1.0)

        onset = true_onset(w, offset, t)
        measured = np.round((onset + w.measure[:, t]) * 60.0) / 60.0
        usable = home & ~w.missing[:, t] & ~w.tz_changed[:, t] & (np.abs(measured) <= params.max_onset_from_plan_min)
        phi = np.column_stack([np.ones(count), offset / 30.0, w.weekend[:, t], w.late_seen[:, t]]).astype(float)
        update(state, phi, measured, usable, params, week=np.full(count, t // 7))
        ok, effect, low, high = shown(state, params)

        out["offset"][:, t], out["prob"][:, t] = offset, prob
        out["gain"][:, t] = np.where(home, response(w.people, offset, t) - response(w.people, np.zeros(count), t), 0.0)
        out["change"][:, t] = np.where(home, np.abs(offset - last_block), 0.0)
        out["estimate"][:, t], out["low"][:, t], out["high"][:, t] = effect, low, high
        out["truth"][:, t] = true_effect(w.people, t)
        flags["home"][:, t], flags["settled"][:, t], flags["shown"][:, t] = home, settled, ok
        last_block = np.where(home, offset, last_block)
    return DampenRun(**out, **flags, settled_target=settled_target)
