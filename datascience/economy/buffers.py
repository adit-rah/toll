"""The buffer suggestion (#145) in the simulator: D97's growing buffer before sleep with each person's
target fitted from their own weeks, against everyone's target at 60.

    uv run python -m economy.buffers --people 1000 --out reports/buffers-sweep.json
    uv run python -m economy.buffers --people 2000 --seed 20261127 --out reports/buffers-final.json

It runs `sim.gap` unchanged (D66's personal timing around the buffer, the assumed tolerance and dropout of
`sim.gap_rule`) and swaps only the Monday judgement for one whose target is per person: before each
Monday's judgement the person's past weeks go through `economy.suggest.target`, as the phone would read
them from its night records. The app offers the fitted target once, in the one-time flow; here it is
refitted every Monday, the most it could move the plan, so a mark that holds here holds for the flow.

Variants:
- `base`: D97's buffer before sleep, 30 growing to 60, the same target for everyone.
- `base-15`: D76's start of 15 instead, as `reports/gap.md` ran it, to separate D97's start from the fit.
- `fitted`: the same with the fitted target, never past 60 (nobody has Health's sign).
- `fitted-raise`: the fitted target with Health's sign for everyone, so everyone who sails through 60
  for three weeks is offered 75, then 90: the most the raise could do.
- `fitted-min3`, `fitted-min6`: the fitted target with 3 or 6 judged weeks needed instead of 4.
- `d66`: no buffer, for reference.
"""

from __future__ import annotations

import argparse
import json
import time
from concurrent.futures import ProcessPoolExecutor
from contextlib import contextmanager
from dataclasses import asdict, dataclass

import numpy as np

import sim.gap as gap_module
from dusk_model.artifact import Params
from export import v0
from sim.dampen_sweep import STRESS, make_world
from sim.gap import D66, Variant, run
from sim.gap_rule import GapRule, Week
from sim.gap_sweep import gap_summary, timing_summary
from sim.run import NIGHTS
from sim.scenarios import SCENARIOS

from .suggest import HARD, HOLD, OFF, SMOOTH, Rule
from .suggest import Week as SuggestWeek
from .suggest import target

D97 = GapRule(start=30, cap=60)


@dataclass(frozen=True)
class Fitting:
    raise_for_all: bool = False  # Health's sign for everyone: the raise's upper bound
    rule: Rule = Rule()


def fitted_judge(fitting: Fitting):
    """`sim.gap_rule.judge` with a per-person target refitted from the person's weeks each Monday."""

    def judge(s, rule: GapRule, monday: int, lock_nights, pauses, off) -> Week:
        count = len(s.gap)
        hard = pauses >= rule.hard_pauses
        smooth = (lock_nights >= rule.smooth_min_nights) & ~hard & ~off
        verdicts = np.where(off, OFF, np.where(hard, HARD, np.where(smooth, SMOOTH, HOLD)))
        history = getattr(s, "history", None)
        if history is None:
            history = [[] for _ in range(count)]
            s.history = history
        for p in range(count):
            history[p].append(SuggestWeek(int(round(s.gap[p])), str(verdicts[p]), int(pauses[p])))
        cap = np.array(
            [
                t if (t := target("before", history[p], fitting.raise_for_all, fitting.rule)) is not None else rule.cap
                for p in range(count)
            ],
            dtype=float,
        )
        s.cap = cap
        none = np.zeros_like(hard)
        if not rule.grows:
            return Week(smooth, hard, off, none, none)
        ease = hard | off
        s.frozen_until = np.where(off, monday + rule.off_freeze_weeks, s.frozen_until)
        s.streak = np.where(smooth, s.streak + 1, 0)
        needed = np.where(s.need_two, 2, 1)
        grow = smooth & (s.streak >= needed) & (monday > s.frozen_until) & ~s.stopped & (s.gap < cap)
        # A fitted target below today's buffer brings it down to the target, as the flow's offer would.
        s.gap = np.minimum(np.clip(s.gap + rule.step * grow - rule.step * ease, 0.0, None), cap)
        s.streak = np.where(grow, 0, s.streak)
        s.need_two = (s.need_two & ~grow) | ease
        s.eased = s.eased | ease
        return Week(smooth, hard, off, grow, ease)

    return judge


@contextmanager
def judged_with(fitting: Fitting | None):
    original = gap_module.judge
    if fitting is not None:
        gap_module.judge = fitted_judge(fitting)
    try:
        yield
    finally:
        gap_module.judge = original


VARIANTS: dict[str, tuple[Variant, Fitting | None]] = {
    "d66": (Variant("d66", rule=None, tolerance=None), None),
    "base": (Variant("base", rule=D97), None),
    "base-15": (Variant("base-15", rule=GapRule()), None),
    "fitted": (Variant("fitted", rule=D97), Fitting()),
    "fitted-raise": (Variant("fitted-raise", rule=D97), Fitting(raise_for_all=True)),
    "fitted-min3": (Variant("fitted-min3", rule=D97), Fitting(rule=Rule(min_weeks=3))),
    "fitted-min6": (Variant("fitted-min6", rule=D97), Fitting(rule=Rule(min_weeks=6))),
}


def extra(r, nights: int) -> dict:
    """What the fitted target changes: where buffers end, and how often they move."""
    on = ~r.dropped[:, -1]
    end = r.gap[on, -1] if on.any() else np.zeros(1)
    moves = (np.diff(r.gap, axis=1) != 0).sum(axis=1)
    return {
        "gap_end_histogram": {str(g): float((end == g).mean()) for g in range(0, 91, 15)},
        "over_60_ever": float((r.gap > 60).any(axis=1).mean()),
        "buffer_moves_per_person": float(moves.mean()),
        "buffer_moves_weeks_5_on": float((np.diff(r.gap[:, 28:], axis=1) != 0).sum(axis=1).mean()),
    }


def job(args: tuple) -> tuple[str, str, dict]:
    name, scenario, people, seed, draws, nights = args
    variant, fitting = VARIANTS[name]
    base = Params.from_artifact(v0.artifact())
    w = make_world(scenario, people, seed, nights)
    with judged_with(fitting):
        r = run(w, base, variant, seed, draws)
    summary = gap_summary(w, r) | timing_summary(w, r, D66.grid) | extra(r, nights)
    summary["max_gap"] = float(r.gap.max())
    return name, scenario, summary


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=1000)
    ap.add_argument("--draws", type=int, default=300)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--nights", type=int, default=NIGHTS)
    ap.add_argument("--only", default="")
    ap.add_argument("--scenarios", default="")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    names = [n for n in VARIANTS if not args.only or n in args.only.split(",")]
    scenarios = [s for s in args.scenarios.split(",") if s] or SCENARIOS + STRESS
    jobs = [(n, s, args.people, args.seed + i, args.draws, args.nights) for n in names for i, s in enumerate(scenarios)]
    started = time.time()
    results: dict = {n: {"variant": asdict(VARIANTS[n][0]), "fitting": asdict(VARIANTS[n][1]) if VARIANTS[n][1] else None,
                         "scenarios": {}} for n in names}
    with ProcessPoolExecutor(args.workers) as pool:
        for name, scenario, summary in pool.map(job, jobs):
            results[name]["scenarios"][scenario] = summary
            print(name, scenario, json.dumps({k: round(v, 3) for k, v in summary.items() if isinstance(v, float)}), flush=True)
    out = {"people_per_scenario": args.people, "draws": args.draws, "seed": args.seed, "nights": args.nights,
           "seconds": round(time.time() - started, 1), "variants": results}
    with open(args.out, "w") as f:
        f.write(json.dumps(out, indent=2, default=str) + "\n")


if __name__ == "__main__":
    main()
