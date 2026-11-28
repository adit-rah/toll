"""Personal timing's start policy (decisions D66): a start held for a week, settling once the answer is known.

For people who opt in, the start is chosen on the first night of each hold and kept to its end:
1. A hold is `hold_nights` nights long. Holds are counted from `EPOCH`, a Monday, so holds of 7 nights
   run Monday to Sunday, by the night's date (the evening it starts).
2. On a hold's first night, the person is **settled** if the insight shows (the start goes to the
   farthest allowed start on the side it supports), or, after `min_nights` usable nights, if the 90%
   range lies inside ±`settle_plan_within_min` (the start goes to the plan, 0). Settling is checked
   afresh at every hold: when the insight no longer holds, the person draws again.
3. A settled person keeps the settled start, except in a share `settled_explore_share` of holds. An
   unsettled person, or a settled one exploring, draws by Thompson sampling with the floor (`policy`).
4. If a held start stops being allowed (the person changed their limits), a new hold is drawn that
   night, to the end of the same period.

The logged chance is exact, as off-policy evaluation needs. Every night of a hold logs the chance of
the hold's draw, given the history up to the hold's first night:
- unsettled: p'(start), the floored Thompson chance;
- settled: share · p'(start) + (1 − share) · [start is the settled start].
The record names the hold by its first night (`hold_start`), so the nights of one draw are grouped,
and says whether the person was settled (`settled`).

The draws, in order, on a hold's first night: `prob_draws` × 4 normals, one uniform for the pick, and,
when the artifact settles, one uniform for exploring. Nothing is drawn on a hold's other nights.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

import numpy as np

from .artifact import Params
from .insights import shown
from .model import State
from .policy import features_for, win_probabilities
from .rng import SplitMix64Batch

EPOCH = date(2001, 1, 1)  # a Monday


def period(night: str | date, params: Params) -> int:
    """The hold a night falls in: whole holds since EPOCH."""
    day = date.fromisoformat(night) if isinstance(night, str) else night
    return (day - EPOCH).days // params.hold_nights


def policy_name(params: Params) -> str:
    """What the night record's `policy` says: "thompson" for v0's nightly draw, "held" for D66's."""
    return "held" if params.hold_nights > 1 or params.settles else "thompson"


@dataclass
class Holds:
    """Each person's current hold. `period` is −1 before the first."""

    period: np.ndarray  # (P,) int64
    start: np.ndarray  # (P,) int64: the hold's first night, as days since EPOCH
    offset: np.ndarray  # (P,) float
    prob: np.ndarray  # (P,)
    settled: np.ndarray  # (P,) bool

    @classmethod
    def none(cls, people: int) -> "Holds":
        return cls(
            period=np.full(people, -1, dtype=np.int64),
            start=np.zeros(people, dtype=np.int64),
            offset=np.zeros(people),
            prob=np.ones(people),
            settled=np.zeros(people, dtype=bool),
        )


def settle(state: State, params: Params, allowed: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """(settled, target) for each person from tonight's state, before tonight's night is learned."""
    ok, effect, low, high = shown(state, params)
    actions = np.array(params.actions, dtype=float)
    reach = np.where(allowed, actions[None, :], np.nan)
    # Linear in the start: the best-supported start is the farthest allowed one on the better side.
    # A positive effect means an earlier start helps.
    side = np.where(effect > 0, np.nanmin(reach, axis=1), np.nanmax(reach, axis=1))
    at_insight = ok & params.settle_at_insight
    band = params.settle_plan_within_min
    at_plan = (band > 0) & (state.nights >= params.min_nights) & (low > -band) & (high < band)
    settled = at_insight | at_plan
    return settled, np.where(at_insight, side, 0.0)


def floored(p: np.ndarray, allowed: np.ndarray, params: Params) -> np.ndarray:
    """p' = (1 − K·floor)·p + floor over the K allowed starts; one allowed start gets 1."""
    k = allowed.sum(axis=1).astype(float)[:, None]
    mixed = np.where(allowed, (1.0 - k * params.min_prob) * p + params.min_prob, 0.0)
    return np.where(k == 1, allowed.astype(float), mixed)


def pick(mixed: np.ndarray, allowed: np.ndarray, u: np.ndarray) -> np.ndarray:
    """Index drawn from each row with one uniform; the last allowed start if rounding leaves none."""
    chosen = np.full(len(u), -1)
    cumulative = np.zeros(len(u))
    for k in range(mixed.shape[1]):
        cumulative = cumulative + mixed[:, k]
        chosen = np.where((chosen < 0) & allowed[:, k] & (u < cumulative), k, chosen)
    last_allowed = np.array([np.flatnonzero(row)[-1] for row in allowed])
    return np.where(chosen < 0, last_allowed, chosen)


def draw(
    state: State,
    weekend: np.ndarray,
    late: np.ndarray,
    allowed: np.ndarray,
    rng: SplitMix64Batch,
    params: Params,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """A new hold for everyone in `state`: (offset, chance, settled)."""
    phi = features_for(params, weekend, late)
    mixed = floored(win_probabilities(state, phi, allowed, rng, params), allowed, params)
    k = pick(mixed, allowed, rng.uniform(1)[:, 0])
    actions = np.array(params.actions, dtype=float)
    rows = np.arange(state.people)
    offset, prob = actions[k], mixed[rows, k]
    if not params.settles:
        return offset, prob, np.zeros(state.people, dtype=bool)
    explore = rng.uniform(1)[:, 0] < params.settled_explore_share
    settled, target = settle(state, params, allowed)
    offset = np.where(settled & ~explore, target, offset)
    share = params.settled_explore_share
    at = (actions[None, :] == offset[:, None]).astype(float)
    p_offset = (mixed * at).sum(axis=1)
    prob = np.where(settled, share * p_offset + (1.0 - share) * (offset == target), p_offset)
    return offset, prob, settled


def choose(
    state: State,
    holds: Holds,
    night: int,
    weekend: np.ndarray,
    late: np.ndarray,
    allowed: np.ndarray,
    rng: SplitMix64Batch,
    params: Params,
) -> Holds:
    """Tonight's hold for each person; `night` is tonight's date as days since EPOCH.

    A person keeps their hold if tonight is in its period and its start is still allowed; everyone
    else draws. Only those who draw advance their generator.
    """
    now = night // params.hold_nights
    actions = np.array(params.actions, dtype=float)
    held_ok = (allowed & (actions[None, :] == holds.offset[:, None])).any(axis=1)
    new = (holds.period != now) | ~held_ok
    out = Holds(
        period=holds.period.copy(),
        start=holds.start.copy(),
        offset=holds.offset.copy(),
        prob=holds.prob.copy(),
        settled=holds.settled.copy(),
    )
    idx = np.flatnonzero(new)
    if len(idx) == 0:
        return out
    sub = state.rows(idx)
    sub_rng = SplitMix64Batch(rng.state[idx])
    offset, prob, settled = draw(sub, weekend[idx], late[idx], allowed[idx], sub_rng, params)
    rng.state[idx] = sub_rng.state
    out.period[idx], out.start[idx] = now, night
    out.offset[idx], out.prob[idx], out.settled[idx] = offset, prob, settled
    return out


def day_number(night: str | date) -> int:
    day = date.fromisoformat(night) if isinstance(night, str) else night
    return (day - EPOCH).days


def week_of(night: str | date) -> int:
    """The calendar week a night falls in, Monday to Sunday, as whole weeks since EPOCH: the unit the
    model's intercept wanders by (#154), whatever the artifact's hold."""
    return day_number(night) // 7


def hold_of(record: dict) -> dict | None:
    """The hold a night record carries, if a held policy chose its start: what the phone keeps to the
    hold's end, and what a rebuild restores. None for "fixed" and "thompson" nights."""
    if record.get("policy") != "held" or record.get("hold_start") is None:
        return None
    return {
        "start": record["hold_start"],
        "offset": int(record["action_offset_min"]),
        "prob": float(record["action_prob"]),
        "settled": bool(record.get("settled") or False),
    }
