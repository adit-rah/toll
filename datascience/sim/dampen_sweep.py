"""Runs the dampened start policies (sim.dampen) through the scenarios and writes what each costs.

    uv run python -m sim.dampen_sweep --people 1000 --out reports/dampening-sweep.json
    uv run python -m sim.dampen_sweep --people 2000 --only v0,weekly,settle-2wk --stress --out reports/dampening-final.json

reports/dampening.md is written by hand from the JSON, with the reasoning.
"""

from __future__ import annotations

import argparse
import json
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np

from dusk_model.artifact import Params
from export import v0

from .criteria import first_insight_night
from .dampen import DampenRun, Policy, allowed_on, run
from .run import NIGHTS, world
from .scenarios import SCENARIOS

FINE = tuple(range(-30, 31, 5))
TENS = (-30, -20, -10, 0, 10, 20, 30)

POLICIES = [
    Policy("v0"),
    # 1. Smaller moves. The floor keeps 30% of the chance spread over the starts, as v0 does.
    Policy("grid15", grid=(-15, 0, 15)),
    Policy("grid15-prior40", grid=(-15, 0, 15), slope_prior_sd=40.0),
    # Phrased per 15 minutes, with the shown range under 30 minutes in those units.
    Policy("grid15-width60", grid=(-15, 0, 15), max_width=60.0),
    Policy("grid20x10", grid=(-20, -10, 0, 10, 20), floor=0.06),
    Policy("grid10x5", grid=(-10, -5, 0, 5, 10), floor=0.06),
    # 2. The plan as the default.
    Policy("k1", explore_per_week=1),
    Policy("k2", explore_per_week=2),
    Policy("k3", explore_per_week=3),
    Policy("k2-uniform", explore_per_week=2, explore="uniform"),
    Policy("plan50", zero_floor=0.5),
    Policy("plan70", zero_floor=0.7),
    # 3. Smoothness: a walk toward the Thompson draw.
    Policy("step5", grid=FINE, floor=0.3 / len(FINE), step=5),
    Policy("step10", grid=FINE, floor=0.3 / len(FINE), step=10),
    Policy("step10-tens", grid=TENS, floor=0.3 / len(TENS), step=10),
    # One start held for a run of nights.
    Policy("dwell3", dwell=3),
    Policy("weekly", dwell=7),
    Policy("fortnight", dwell=14),
    Policy("weekly-step10", grid=TENS, floor=0.3 / len(TENS), dwell=7, step=10),
    # 4. Explore, then settle where the evidence points and explore rarely.
    Policy("settle-insight", settle="insight"),
    Policy("settle-insight-step10", grid=TENS, floor=0.3 / len(TENS), settle="insight", step=10),
    Policy("settle-conf90", settle="confident", settle_confidence=0.9),
    Policy("settle-conf95", settle="confident", settle_confidence=0.95),
    Policy("settle-insight-plan15", settle="insight", settle_plan_within=15.0),
    # 5. Combinations.
    Policy("k2-settle", explore_per_week=2, settle="insight"),
    Policy("k3-settle-step10", grid=TENS, floor=0.3 / len(TENS), explore_per_week=3, settle="insight", step=10),
    Policy("weekly-settle", dwell=7, settle="insight", after_settle_per_week=0.5),
    Policy("weekly-settle-plan15", dwell=7, settle="insight", settle_plan_within=15.0),
    Policy("weekly-settle-plan15-max15", dwell=7, settle="insight", settle_plan_within=15.0, settle_max=15),
    Policy("weekly-settle-plan10", dwell=7, settle="insight", settle_plan_within=10.0),
    Policy("weekly-conf95", dwell=7, settle="confident", settle_confidence=0.95),
    Policy("weekly15-settle-plan15", grid=(-15, 0, 15), dwell=7, settle="insight", settle_plan_within=15.0),
    Policy("weekly15", grid=(-15, 0, 15), dwell=7),
    Policy("weekly-plan50", dwell=7, zero_floor=0.5),
    Policy("dwell3-settle", dwell=3, settle="insight"),
    Policy("dwell3-settle-plan15", dwell=3, settle="insight", settle_plan_within=15.0),
]
BY_NAME = {p.name: p for p in POLICIES}
STRESS = ["null+drift", "differ+drift", "differ+fade"]
DRIFT_SD = 2.0  # minutes a night: the person's usual onset wanders, about 15 min over 8 weeks


def make_world(scenario: str, people: int, seed: int, nights: int = NIGHTS):
    name, _, twist = scenario.partition("+")
    w = world(name, people, seed, fade=twist == "fade", nights=nights)
    if twist == "drift":
        steps = np.random.default_rng([seed, 7]).normal(0.0, DRIFT_SD, w.noise.shape)
        w.noise = w.noise + np.cumsum(steps, axis=1)
    return w


def covered(r: DampenRun, night: int) -> np.ndarray:
    return (r.low[:, night] <= r.truth[:, night]) & (r.truth[:, night] <= r.high[:, night])


def summarize(w, r: DampenRun, grid: tuple[int, ...]) -> dict:
    home = r.home
    weeks = NIGHTS / 7
    first = first_insight_night(r.shown)
    big = np.abs(w.people.truth[:, 1]) >= 15
    late = slice(NIGHTS - 14, NIGHTS)
    allowed = allowed_on(np.array(grid, dtype=float), w.people.allowed)
    on_grid = np.zeros_like(home)
    for k, a in enumerate(grid):
        on_grid |= (r.offset == a) & allowed[:, k][:, None]
    randomized = home & (r.prob < 1.0)
    wrong = r.shown & (np.sign(r.estimate) != np.sign(r.truth)) & (r.truth != 0)
    return {
        "benefit": float(r.gain[home].mean()),
        "benefit_weeks_5_8": float(r.gain[:, 28:][home[:, 28:]].mean()),
        "coverage_end": float(covered(r, NIGHTS - 1).mean()),
        "ever_shown": float(r.shown.any(axis=1).mean()),
        "ever_shown_wrong_sign": float(wrong.any(axis=1).mean()),
        "shown_by_28": float((first <= 28).mean()),
        "shown_by_56": float((first <= 56).mean()),
        "big_effect_by_56": float((first[big] <= 56).mean()) if big.any() else None,
        "settled_by_56": float(r.settled[:, -1].mean()),
        "settled_at_plan": float((r.settled[:, -1] & (r.settled_target == 0)).mean()),
        "big_settled_at_plan": float((r.settled[big, -1] & (r.settled_target[big] == 0)).mean()) if big.any() else None,
        # A positive true effect means an earlier start helps, so the right side is below zero.
        "settled_wrong_side": float((r.settled[:, -1] & (r.settled_target * r.truth[:, -1] > 0)).mean()),
        "moved_nights_per_week": float(((r.offset != 0) & home).sum(axis=1).mean() / weeks),
        "mean_abs_offset": float(np.abs(r.offset[home]).mean()),
        "mean_abs_change": float(r.change[home].mean()),
        "changes_per_week": float(((r.change > 0) & home).sum(axis=1).mean() / weeks),
        "changes_per_week_last_2": float(((r.change[:, late] > 0) & home[:, late]).sum(axis=1).mean() / 2),
        "moved_nights_per_week_last_2": float(((r.offset[:, late] != 0) & home[:, late]).sum(axis=1).mean() / 2),
        "randomized_share": float(randomized.sum() / home.sum()),
        "outside_allowed": int((home & ~on_grid).sum()),
        "zero_prob_chosen": int((home & (r.prob <= 0)).sum()),
        "block_nights": int(home.sum()),
    }


def job(args: tuple) -> tuple[str, str, dict]:
    name, scenario, people, seed, draws = args
    policy = BY_NAME[name]
    base = Params.from_artifact(v0.artifact())
    w = make_world(scenario, people, seed)
    return name, scenario, summarize(w, run(w, base, policy, seed, draws), policy.grid)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=1000)
    ap.add_argument("--draws", type=int, default=300)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--only", default="", help="comma-separated policy names")
    ap.add_argument("--stress", action="store_true", help="also drift and fade (" + ", ".join(STRESS) + ")")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default="reports/dampening-sweep.json")
    args = ap.parse_args()
    names = [n for n in args.only.split(",") if n] or [p.name for p in POLICIES]
    scenarios = SCENARIOS + (STRESS if args.stress else [])
    jobs = [(n, s, args.people, args.seed + i, args.draws) for n in names for i, s in enumerate(scenarios)]
    started = time.time()
    results: dict = {n: {"policy": dict(BY_NAME[n].__dict__), "scenarios": {}} for n in names}
    with ProcessPoolExecutor(args.workers) as pool:
        for name, scenario, summary in pool.map(job, jobs):
            results[name]["scenarios"][scenario] = summary
            print(name, scenario, json.dumps({k: round(v, 3) if isinstance(v, float) else v for k, v in summary.items()}), flush=True)
    out = {"people_per_scenario": args.people, "draws": args.draws, "seed": args.seed,
           "seconds": round(time.time() - started, 1), "policies": results}
    Path(args.out).write_text(json.dumps(out, indent=2) + "\n")


if __name__ == "__main__":
    main()
