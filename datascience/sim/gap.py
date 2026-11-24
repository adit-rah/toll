"""Personal timing (D66) around a lock that starts a growing gap before bed (D76).

An exploration harness, not a new artifact. The model, its update and the insight rule are v0's. The
start policy is D66's: a start from −30, 0 and +30 minutes around the plan, drawn by Thompson sampling on
Mondays and held all week, settling at the insight or at the plan once the 90% range is inside ±15. What
is new is the plan: bed minus the gap, which grows or eases each Monday (`sim.gap_rule`).

Sleep onset is still measured from bed, which never moves (nor does the wake time). The gap moves the
lock earlier, and a person's effect of an earlier start applies to it as to the policy's own moves:
onset falls by c1 per 30 minutes of gap. That is an assumption: nothing has measured a lock 60 minutes
before bed. The model sees only the start's offset from the plan (`feature="plan"`, today's artifact), or
the start from bed (`feature="bed"`, which would need a new artifact).

D76's link between the two: if the insight says earlier helps, the gap keeps growing; if the start
settles at the plan, growth stops; if later helps, the gap eases a step and stops. `timing="after"` is
D76's fallback: personal timing waits until the gap settles (`GapState.settled`). `timing="first"` is the
other order: the gap holds at its start until personal timing settles, and grows only if earlier helps.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from dusk_model.artifact import Params
from dusk_model.insights import shown
from dusk_model.model import State, prior_state, update
from dusk_model.policy import features_for, win_probabilities

from .dampen import NumpyNormals, Policy, allowed_on, floor_mix, sample
from .gap_rule import GapRule, GapState, Tolerance, dose, judge, luck, pause_chance
from .run import World, true_onset
from .scenarios import response, true_effect

D66 = Policy("weekly-settle-plan15", dwell=7, settle="insight", settle_plan_within=15.0)
TIMINGS = ("none", "together", "after", "first")


@dataclass(frozen=True)
class Variant:
    name: str
    rule: GapRule | None = field(default_factory=GapRule)  # None: the lock starts at bed, as in D66
    timing: str = "together"
    feature: str = "plan"
    tolerance: Tolerance | None = field(default_factory=Tolerance)  # None: nobody pauses or leaves
    couple: bool = True
    dose: str = "linear"
    loosen_sd: float | None = None  # when the gap changes, the usual onset may have moved by this sd


def loosen_intercept(state: State, mask: np.ndarray, sd: float) -> None:
    """Adds sd² to the intercept's variance and keeps the mean (Sherman–Morrison on the precision), so
    a level shift at a gap change is not read as the start's effect. Not the phone's arithmetic."""
    lam = state.precision
    mu = np.linalg.solve(lam, state.b[..., None])[..., 0]
    col = lam[:, :, 0]
    loosened = lam - (sd * sd) * col[:, :, None] * col[:, None, :] / (1.0 + sd * sd * lam[:, 0, 0])[:, None, None]
    state.precision = np.where(mask[:, None, None], loosened, lam)
    state.b = np.where(mask[:, None], np.einsum("pij,pj->pi", state.precision, mu), state.b)


@dataclass
class GapRun:
    offset: np.ndarray  # personal timing's offset from the plan; 0 when the lock didn't run
    prob: np.ndarray
    gain: np.ndarray  # personal timing's gain: onset minus onset at the plan, same night
    home: np.ndarray  # the lock ran: at home and Screen Time on
    change: np.ndarray
    settled: np.ndarray
    settled_target: np.ndarray
    shown: np.ndarray
    estimate: np.ndarray
    low: np.ndarray
    high: np.ndarray
    truth: np.ndarray
    gap: np.ndarray  # (P, nights)
    start: np.ndarray  # lock start in minutes from bed (below zero is before bed); 0 when it didn't run
    lock_change: np.ndarray  # |start − last lock night's start|
    total_gain: np.ndarray  # onset against a lock at bed, nights at home; 0 once Screen Time is off for good
    at_home: np.ndarray
    dropped: np.ndarray
    pauses: np.ndarray
    timing_on: np.ndarray
    hard_weeks: np.ndarray  # (P,)
    off_weeks: np.ndarray
    judged_weeks: np.ndarray


def run(w: World, base: Params, v: Variant, seed: int, draws: int = 300, policy: Policy = D66) -> GapRun:
    if v.timing not in TIMINGS or v.feature not in ("plan", "bed"):
        raise ValueError(f"unknown variant {v}")
    if v.dose != "linear" and v.timing != "none":
        raise ValueError("a saturating dose changes the start's local effect; only without personal timing")
    params = policy.params(base, draws)
    count, nights = w.away.shape
    grid = np.array(policy.grid, dtype=float)
    allowed = allowed_on(grid, w.people.allowed)
    gen = np.random.default_rng([seed, 99])
    normals = NumpyNormals(gen, count)
    state = prior_state(params, count)
    tol = v.tolerance
    lk = luck(count, nights, seed, tol or Tolerance())
    rule = v.rule or GapRule(grows=False, start=0)
    gs = GapState.start(count, rule)

    current, last_block, last_start = np.zeros(count), np.zeros(count), np.full(count, np.nan)
    settled, exploring = np.zeros(count, dtype=bool), np.zeros(count, dtype=bool)
    settled_target = np.zeros(count)
    active = np.full(count, v.timing in ("together", "first"))
    dropped, eased_for_later = np.zeros(count, dtype=bool), np.zeros(count, dtype=bool)
    week_nights, week_pauses = np.zeros(count, dtype=np.int64), np.zeros(count, dtype=np.int64)
    hard_weeks, off_weeks, judged = (np.zeros(count, dtype=np.int64) for _ in range(3))
    rate = policy.after_settle_per_week / 7.0

    keys = ("offset", "prob", "gain", "change", "estimate", "low", "high", "truth", "gap", "start", "lock_change", "total_gain")
    out = {k: np.zeros((count, nights)) for k in keys}
    flags = {k: np.zeros((count, nights), dtype=bool) for k in ("home", "settled", "shown", "at_home", "dropped", "pauses", "timing_on")}
    for t in range(nights):
        if t % 7 == 0 and t > 0:
            monday = t // 7
            on = ~dropped
            hard = on & (week_pauses >= rule.hard_pauses)
            off = hard & (lk.off_u[:, monday] < (tol.off_per_hard_week if tol else 0.0))
            before = gs.gap.copy()
            if v.couple:
                gs.stopped = settled & (settled_target >= 0)
                if v.timing == "first":
                    gs.stopped |= ~settled
                later = settled & (settled_target > 0) & ~eased_for_later & on
                gs.gap = np.where(later, np.maximum(gs.gap - rule.step, 0.0), gs.gap) if rule.grows else gs.gap
                gs.need_two |= later
                eased_for_later |= later
            judge(gs, rule, monday, np.where(on, week_nights, 0), week_pauses, off)
            if v.loosen_sd is not None:
                loosen_intercept(state, gs.gap != before, v.loosen_sd)
            dropped |= off & (lk.quit_u[:, monday] < (tol.quit_share if tol else 0.0))
            hard_weeks += hard
            off_weeks += off
            judged += on
            if v.timing == "after":
                active |= gs.settled(rule)
            week_nights[:], week_pauses[:] = 0, 0
        gap = gs.gap.copy()
        at_home = ~w.away[:, t]
        lock = at_home & ~dropped

        phi_k = features_for(params, w.weekend[:, t], w.late_seen[:, t])
        if v.feature == "bed":
            phi_k[..., 1] = (grid[None, :] - gap[:, None]) / 30.0
        p = win_probabilities(state, phi_k, allowed, normals, params)
        thompson = floor_mix(p, allowed, policy.floor, policy.zero_floor, int(np.flatnonzero(grid == 0)[0]))
        ok, effect, low, high = shown(state, params)

        # D66: settle at the insight, on the side it supports, or at the plan once the range is inside ±15.
        reach = np.where(allowed, grid[None, :], np.nan)
        best = np.where(effect > 0, np.nanmin(reach, axis=1), np.nanmax(reach, axis=1))
        now = ok & active
        plan_ok = (low > -policy.settle_plan_within) & (high < policy.settle_plan_within)
        plan_ok &= (state.nights >= params.min_nights) & active
        best = np.where(plan_ok & ~now, 0.0, best)
        now = now | plan_ok
        settled_target = np.where(now, best, settled_target)
        settled = settled | now

        u_choice, u_explore = gen.uniform(size=count), gen.uniform(size=count)
        drawn = grid[sample(thompson, u_choice)]
        same = (grid[None, :] == current[:, None]).astype(float)
        if t % policy.dwell == 0:
            target, target_dist = drawn, thompson
            exploring = u_explore < rate
            explore_target, explore_now, explore_now_dist = drawn, np.full(count, rate), thompson
        else:
            target, target_dist = current, same
            explore_target, explore_now, explore_now_dist = current, exploring.astype(float), same
        target = np.where(settled, np.where(exploring, explore_target, settled_target), target)
        held = (grid[None, :] == settled_target[:, None]).astype(float)
        mix = explore_now[:, None]
        target_dist = np.where(settled[:, None], mix * explore_now_dist + (1 - mix) * held, target_dist)
        target = np.where(active, target, 0.0)
        target_dist = np.where(active[:, None], target_dist, (grid == 0)[None, :].astype(float))
        current = target
        prob = (target_dist * (grid[None, :] == target[:, None])).sum(axis=1)
        offset = np.where(lock, target, 0.0)
        prob = np.where(lock, prob, 1.0)

        if tol is not None:
            chance = pause_chance(gap - offset, lk.comfort, tol)
            paused = lock & (lk.pause_u[:, t] < chance) & (week_pauses < tol.pauses_per_week)
        else:
            paused = np.zeros(count, dtype=bool)
        week_pauses += paused
        week_nights += lock

        slope = true_effect(w.people, t)
        lead_gain = np.where(lock, slope * gap / 30.0, 0.0)
        onset = true_onset(w, offset, t) - lead_gain
        measured = np.round((onset + w.measure[:, t]) * 60.0) / 60.0
        usable = lock & ~w.missing[:, t] & ~w.tz_changed[:, t] & (np.abs(measured) <= params.max_onset_from_plan_min)
        x = (offset - np.where(lock, gap, 0.0)) / 30.0 if v.feature == "bed" else offset / 30.0
        phi = np.column_stack([np.ones(count), x, w.weekend[:, t], w.late_seen[:, t]]).astype(float)
        update(state, phi, measured, usable, params)
        ok, effect, low, high = shown(state, params)

        start = offset - gap
        own = response(w.people, offset, t) - response(w.people, np.zeros(count), t)
        out["offset"][:, t], out["prob"][:, t] = offset, prob
        out["gain"][:, t] = np.where(lock, own, 0.0)
        out["total_gain"][:, t] = np.where(lock, own - slope * dose(gap, v.dose) / 30.0, 0.0)
        out["change"][:, t] = np.where(lock, np.abs(offset - last_block), 0.0)
        out["lock_change"][:, t] = np.where(lock & ~np.isnan(last_start), np.abs(start - last_start), 0.0)
        out["estimate"][:, t], out["low"][:, t], out["high"][:, t] = effect, low, high
        out["truth"][:, t], out["gap"][:, t], out["start"][:, t] = slope, gap, np.where(lock, start, 0.0)
        flags["home"][:, t], flags["settled"][:, t], flags["shown"][:, t] = lock, settled, ok
        flags["at_home"][:, t], flags["dropped"][:, t], flags["pauses"][:, t] = at_home, dropped, paused
        flags["timing_on"][:, t] = active
        last_block = np.where(lock, offset, last_block)
        last_start = np.where(lock, start, last_start)
    return GapRun(
        **out, **flags, settled_target=settled_target, hard_weeks=hard_weeks, off_weeks=off_weeks, judged_weeks=judged
    )
