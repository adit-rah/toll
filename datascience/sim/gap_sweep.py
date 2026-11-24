"""Runs the growing gap (sim.gap) through the scenarios: D66's marks with the gap as the plan, and the
gap's own trade-offs against fixed gaps.

    uv run python -m sim.gap_sweep marks --people 1000 --out reports/gap-sweep.json
    uv run python -m sim.gap_sweep marks --people 2000 --seed 20261124 --only d66,B,C,D --out reports/gap-final.json
    uv run python -m sim.gap_sweep tradeoffs --people 2000 --only "*/base" --out reports/gap-tradeoffs.json
    uv run python -m sim.gap_sweep pool run1.json run2.json --out reports/gap-seeds.json

The full list of runs behind the report is at the top of reports/gap.md.

reports/gap.md is written by hand from the JSON, with the reasoning.
"""

from __future__ import annotations

import argparse
from fnmatch import fnmatch
import json
import time
from concurrent.futures import ProcessPoolExecutor
from dataclasses import asdict
from pathlib import Path

import numpy as np

from dusk_model.artifact import Params
from export import v0

from .criteria import first_insight_night
from .dampen import allowed_on
from .dampen_sweep import STRESS, make_world
from .gap import D66, GapRun, Variant, run
from .gap_rule import GapRule, Tolerance
from .run import NIGHTS
from .scenarios import SCENARIOS

MARKS = [
    Variant("d66", rule=None, tolerance=None),
    Variant("d66-tolerance", rule=None),
    Variant("B"),
    Variant("B-comfortable", tolerance=None),
    Variant("B-comfort30", tolerance=Tolerance(comfort_mean=30.0)),
    Variant("B-comfort60", tolerance=Tolerance(comfort_mean=60.0)),
    Variant("B-bed", feature="bed"),
    Variant("B-uncoupled", couple=False),
    Variant("D", timing="after"),
    Variant("D-comfortable", timing="after", tolerance=None),
    Variant("C", timing="first"),
    # When the gap changes, the model allows that the usual onset moved (sd 10 min): a new artifact.
    Variant("B-loosen", loosen_sd=10.0),
    Variant("B-comfortable-loosen", tolerance=None, loosen_sd=10.0),
    Variant("B-comfort60-loosen", tolerance=Tolerance(comfort_mean=60.0), loosen_sd=10.0),
    Variant("D-loosen", timing="after", loosen_sd=10.0),
    Variant("D-comfortable-loosen", timing="after", tolerance=None, loosen_sd=10.0),
    Variant("B-loosen5", loosen_sd=5.0),
    Variant("B-comfortable-loosen5", tolerance=None, loosen_sd=5.0),
]

RULES = {
    "fixed0": GapRule(grows=False, start=0),
    "fixed15": GapRule(grows=False, start=15),
    "fixed30": GapRule(grows=False, start=30),
    "fixed45": GapRule(grows=False, start=45),
    "fixed60": GapRule(grows=False, start=60),
    "grow": GapRule(),
}
ASSUMPTIONS = {
    "base": (Tolerance(), "linear"),
    "comfort30": (Tolerance(comfort_mean=30.0), "linear"),
    "comfort60": (Tolerance(comfort_mean=60.0), "linear"),
    "off10": (Tolerance(off_per_hard_week=0.1), "linear"),
    "off40": (Tolerance(off_per_hard_week=0.4), "linear"),
    "saturating": (Tolerance(), "saturating"),
}
TRADEOFFS = [
    Variant(f"{rule}/{assume}", rule=r, timing="none", tolerance=tol, dose=dose)
    for assume, (tol, dose) in ASSUMPTIONS.items()
    for rule, r in RULES.items()
]
BY_NAME = {v.name: v for v in MARKS + TRADEOFFS}


def per_week(mask: np.ndarray) -> float:
    return float(mask.sum(axis=1).mean() / (mask.shape[1] / 7))


def gap_summary(w, r: GapRun) -> dict:
    nights = r.home.shape[1]
    at_home = r.at_home
    late = slice(nights - 14, nights)
    on_end = ~r.dropped[:, -1]
    hurt = w.people.truth[:, 1] < 0
    made_later = r.total_gain.sum(axis=1) > 0
    return {
        "sleep_vs_bed": float(r.total_gain[at_home].mean()),
        "sleep_vs_bed_weeks_5_8": float(r.total_gain[:, 28:][at_home[:, 28:]].mean()),
        "made_later_share": float(made_later.mean()),
        "hurt_made_later_share": float(made_later[hurt].mean()) if hurt.any() else None,
        "dropout": float(r.dropped[:, -1].mean()),
        "hard_week_share": float(r.hard_weeks.sum() / max(1, r.judged_weeks.sum())),
        "off_week_share": float(r.off_weeks.sum() / max(1, r.judged_weeks.sum())),
        "mean_gap_on_lock_nights": float(r.gap[r.home].mean()),
        "gap_end_mean_still_on": float(r.gap[on_end, -1].mean()) if on_end.any() else None,
        "reached_60": float((r.gap >= 60).any(axis=1).mean()),
        "at_60_end_still_on": float((r.gap[on_end, -1] >= 60).mean()) if on_end.any() else None,
        "gap_end_histogram": {str(g): float((r.gap[on_end, -1] == g).mean()) for g in range(0, 61, 15)},
        "pause_nights_per_week": per_week(r.pauses),
        "lock_changes_per_week": per_week((r.lock_change > 0) & r.home),
        "lock_changes_per_week_last_2": per_week(((r.lock_change > 0) & r.home)[:, late]),
        "mean_abs_lock_change": float(r.lock_change[r.home].mean()),
        "max_gap": float(r.gap.max()),
        "max_lead": float(-r.start[r.home].min()),
    }


def timing_summary(w, r: GapRun, grid: tuple[int, ...]) -> dict:
    home = r.home
    nights = home.shape[1]
    last = nights - 1
    first = first_insight_night(r.shown)
    big = np.abs(w.people.truth[:, 1]) >= 15
    timed = r.timing_on[:, -1]
    allowed = allowed_on(np.array(grid, dtype=float), w.people.allowed)
    on_grid = np.zeros_like(home)
    for k, a in enumerate(grid):
        on_grid |= (r.offset == a) & allowed[:, k][:, None]
    covered = (r.low[:, last] <= r.truth[:, last]) & (r.truth[:, last] <= r.high[:, last])
    wrong = r.shown & (np.sign(r.estimate) != np.sign(r.truth)) & (r.truth != 0)
    started = np.where(r.timing_on.any(axis=1), r.timing_on.argmax(axis=1), np.inf)
    late = slice(nights - 14, nights)
    return {
        "benefit": float(r.gain[home].mean()),
        "benefit_weeks_5_8": float(r.gain[:, 28:][home[:, 28:]].mean()),
        "coverage_end": float(covered.mean()),
        "coverage_end_timed": float(covered[timed].mean()) if timed.any() else None,
        # Above zero: the estimate overstates the effect's size, in minutes per 30.
        "exaggeration_end": float(((r.estimate[:, last] - r.truth[:, last]) * np.sign(r.truth[:, last])).mean()),
        "ever_shown": float(r.shown.any(axis=1).mean()),
        "ever_shown_wrong_sign": float(wrong.any(axis=1).mean()),
        "shown_by_28": float((first <= 28).mean()),
        "shown_by_56": float((first <= 56).mean()),
        "shown_by_end": float((first <= nights).mean()),
        "big_effect_by_56": float((first[big] <= 56).mean()) if big.any() else None,
        "big_effect_by_56_still_on": float((first[big & ~r.dropped[:, -1]] <= 56).mean()) if big.any() else None,
        "big_effect_by_end": float((first[big] <= nights).mean()) if big.any() else None,
        "big_effect_by_56_nights_of_timing": float((first[big] <= started[big] + 56).mean()) if big.any() else None,
        "timing_started": float(timed.mean()),
        "timing_start_night_median": float(np.median(started)) if np.isfinite(np.median(started)) else None,
        "settled_by_end": float(r.settled[:, -1].mean()),
        "settled_at_plan": float((r.settled[:, -1] & (r.settled_target == 0)).mean()),
        "big_settled_at_plan": float((r.settled[big, -1] & (r.settled_target[big] == 0)).mean()) if big.any() else None,
        "settled_wrong_side": float((r.settled[:, -1] & (r.settled_target * r.truth[:, -1] > 0)).mean()),
        "changes_per_week": per_week((r.change > 0) & home),
        "changes_per_week_last_2": per_week(((r.change > 0) & home)[:, late]),
        "outside_allowed": int((home & ~on_grid).sum()),
        "zero_prob_chosen": int((home & (r.prob <= 0)).sum()),
        "block_nights": int(home.sum()),
    }


def job(args: tuple) -> tuple[str, str, dict]:
    name, scenario, people, seed, draws, nights = args
    v = BY_NAME[name]
    base = Params.from_artifact(v0.artifact())
    w = make_world(scenario, people, seed, nights)
    r = run(w, base, v, seed, draws)
    summary = gap_summary(w, r)
    if v.timing != "none":
        summary |= timing_summary(w, r, D66.grid)
    return name, scenario, summary


POOLED = ("big_effect_by_56", "big_effect_by_56_still_on", "coverage_end", "ever_shown", "dropout", "benefit")


def pool_seeds(paths: list[str]) -> dict:
    """Mean, low and high of the marks over several runs with different seeds (one JSON each)."""
    runs = [json.loads(Path(p).read_text()) for p in paths]
    out: dict = {"runs": [{"path": Path(p).name, "seed": r["seed"], "people": r["people_per_scenario"]} for p, r in zip(paths, runs)],
                 "variants": {}}
    for r in runs:
        for name, v in r["variants"].items():
            for scenario, summary in v["scenarios"].items():
                for key in POOLED:
                    if summary.get(key) is not None:
                        out["variants"].setdefault(name, {}).setdefault(scenario, {}).setdefault(key, []).append(summary[key])
    for scenarios in out["variants"].values():
        for keys in scenarios.values():
            for key, values in keys.items():
                keys[key] = {"mean": float(np.mean(values)), "low": min(values), "high": max(values), "runs": len(values)}
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("part", choices=["marks", "tradeoffs", "pool"])
    ap.add_argument("inputs", nargs="*", help="pool: the runs to pool")
    ap.add_argument("--people", type=int, default=1000)
    ap.add_argument("--draws", type=int, default=300)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--nights", type=int, default=NIGHTS)
    ap.add_argument("--only", default="", help="comma-separated variant names or patterns (*/base)")
    ap.add_argument("--scenarios", default="", help="comma-separated; default: all six and the stress ones")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    if args.part == "pool":
        Path(args.out).write_text(json.dumps(pool_seeds(args.inputs), indent=2) + "\n")
        return
    pool_of = MARKS if args.part == "marks" else TRADEOFFS
    wanted = [n for n in args.only.split(",") if n]
    names = [v.name for v in pool_of if not wanted or any(fnmatch(v.name, n) for n in wanted)]
    default = SCENARIOS + STRESS if args.part == "marks" else ["differ", "same"]
    scenarios = [s for s in args.scenarios.split(",") if s] or default
    jobs = [(n, s, args.people, args.seed + i, args.draws, args.nights) for n in names for i, s in enumerate(scenarios)]
    started = time.time()
    results: dict = {n: {"variant": asdict(BY_NAME[n]), "scenarios": {}} for n in names}
    with ProcessPoolExecutor(args.workers) as pool:
        for name, scenario, summary in pool.map(job, jobs):
            results[name]["scenarios"][scenario] = summary
            short = {k: round(v, 3) for k, v in summary.items() if isinstance(v, float)}
            print(name, scenario, json.dumps(short), flush=True)
    out = {"people_per_scenario": args.people, "draws": args.draws, "seed": args.seed, "nights": args.nights,
           "seconds": round(time.time() - started, 1), "variants": results}
    Path(args.out).write_text(json.dumps(out, indent=2) + "\n")


if __name__ == "__main__":
    main()
