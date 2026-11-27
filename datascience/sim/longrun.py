"""False insights and learning over a year of nights, for v1 and the variants tuned for #117.

    uv run python -m sim.longrun --people 1000 --out reports/longrun-sweep.json
    uv run python -m sim.longrun --people 2000 --seed 20261127 --only v1 --out reports/longrun-v1.json

The 5% mark on false insights was set at night 56, but the insight is checked every night for as long
as Dusk is used. Each variant is an artifact (`export/v1.py` with some numbers changed) run through the
simulator's own loop (`sim.run`) with the policy and insight rule the phone runs. reports/longrun.md is
written by hand from the JSON, with the reasoning.
"""

from __future__ import annotations

import argparse
import json
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np

from dusk_model.artifact import Params
from export import v0, v1

from .criteria import changes_per_week, first_insight_night
from .dampen_sweep import make_world as drifted_world
from .run import NIGHTS, Run, run

YEAR = 364
WEEKS = (8, 12, 26, 52)
SCENARIOS = ["null", "null+wander", "null+drift", "differ", "differ+wander", "differ+drift", "same"]
WANDER_SD = 15.0
WANDER_DAYS = 28.0

NO_SPEND = {"zero_test_spend_after": 0, "zero_test_spend_power": 0.0}
VARIANTS: dict[str, dict | None] = {
    "v0": None,  # nightly Thompson, the v0 artifact
    "d66": NO_SPEND,  # D66's policy with v0's fixed zero test: #117 as found
    "z99": {"zero_test_interval": 0.99} | NO_SPEND,
    "z995": {"zero_test_interval": 0.995} | NO_SPEND,
    "spend28-1": {"zero_test_spend_after": 28, "zero_test_spend_power": 1.0},
    "spend40-1": {"zero_test_spend_after": 40, "zero_test_spend_power": 1.0},
    "spend40-1.5": {"zero_test_spend_after": 40, "zero_test_spend_power": 1.5},
    "spend40-2": {"zero_test_spend_after": 40, "zero_test_spend_power": 2.0},
    "spend56-1.5": {"zero_test_spend_after": 56, "zero_test_spend_power": 1.5},
    "spend56-2": {"zero_test_spend_after": 56, "zero_test_spend_power": 2.0},
    "spend28-1.5": {"zero_test_spend_after": 28, "zero_test_spend_power": 1.5},
    "spend28-2": {"zero_test_spend_after": 28, "zero_test_spend_power": 2.0},
    "spend34-2": {"zero_test_spend_after": 34, "zero_test_spend_power": 2.0},
    "spend40-3": {"zero_test_spend_after": 40, "zero_test_spend_power": 3.0},
    "spend20-1": {"zero_test_spend_after": 20, "zero_test_spend_power": 1.0},
    "spend30-2": {"zero_test_spend_after": 30, "zero_test_spend_power": 2.0},
    "v1": {},
}


def artifact_for(name: str) -> dict:
    over = VARIANTS[name]
    return v0.artifact() if over is None else v1.artifact(**over)


def make_world(scenario: str, people: int, seed: int, nights: int):
    """`sim.dampen_sweep`'s scenarios, plus "+wander": the usual onset wanders and comes back, an AR(1)
    with sd 15 minutes and a 4-week memory. Over a year the random-walk drift wanders about 38 minutes,
    which is the 8-week stress carried past where it means anything; the wander is the year-long one."""
    name, _, twist = scenario.partition("+")
    if twist != "wander":
        return drifted_world(scenario, people, seed, nights=nights)
    w = drifted_world(name, people, seed, nights=nights)
    rho = float(np.exp(-1.0 / WANDER_DAYS))
    steps = np.random.default_rng([seed, 8]).normal(0.0, WANDER_SD * np.sqrt(1 - rho * rho), w.noise.shape)
    level = np.zeros(people)
    start = np.random.default_rng([seed, 9]).normal(0.0, WANDER_SD, people)
    for t in range(nights):
        level = start if t == 0 else rho * level + steps[:, t]
        w.noise[:, t] = w.noise[:, t] + level
    return w


def summarize(w, r: Run, nights: int) -> dict:
    first = first_insight_night(r.shown)
    effect = np.abs(w.people.truth[:, 1])
    big = effect >= 15
    out = {f"ever_shown_by_week_{k}": float((first <= 7 * k).mean()) for k in WEEKS if 7 * k <= nights}
    out["ever_shown_by_week"] = [float((first <= 7 * (k + 1)).mean()) for k in range(nights // 7)]
    # A shown insight is withdrawn quietly when it stops passing; how many see one tonight.
    out["shown_at_end"] = float(r.shown[:, -1].mean())
    out["shown_by_28"] = float((first <= 28).mean())
    out["shown_by_56"] = float((first <= 56).mean())
    out["big_effect_by_56"] = float((first[big] <= 56).mean()) if big.any() else None
    out["big_effect_by_end"] = float((first[big] <= nights).mean()) if big.any() else None
    for night in (NIGHTS, nights):
        cov = (r.low[:, night - 1] <= r.truth[:, night - 1]) & (r.truth[:, night - 1] <= r.high[:, night - 1])
        out[f"coverage_night_{night}"] = float(cov.mean())
    wrong = r.shown & (np.sign(r.estimate) != np.sign(r.truth)) & (r.truth != 0)
    out["ever_shown_wrong_sign"] = float(wrong.any(axis=1).mean())
    out["changes_per_week"] = changes_per_week(r)
    out["settled_at_end"] = float(r.settled[:, -1].mean())
    out["settled_at_plan_at_end"] = float((r.settled[:, -1] & (r.held[:, -1] == 0)).mean())
    out["benefit"] = None
    return out


def job(args: tuple) -> tuple[str, str, dict]:
    name, scenario, people, seed, nights = args
    params = Params.from_artifact(artifact_for(name))
    w = make_world(scenario, people, seed, nights=nights)
    r = run(w, params, "thompson", seed)
    fixed = run(w, params, "fixed", seed)
    out = summarize(w, r, nights)
    home = r.home
    out["benefit"] = float((r.true_onset[home] - fixed.true_onset[home]).mean())
    return name, scenario, out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=1000)
    ap.add_argument("--nights", type=int, default=YEAR)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--only", default=",".join(VARIANTS))
    ap.add_argument("--scenarios", default=",".join(SCENARIOS))
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default="reports/longrun-sweep.json")
    args = ap.parse_args()
    names, scenarios = args.only.split(","), args.scenarios.split(",")
    started = time.time()
    jobs = [(n, s, args.people, args.seed + i, args.nights) for n in names for i, s in enumerate(scenarios)]
    results: dict = {n: {"artifact": artifact_for(n)} for n in names}
    with ProcessPoolExecutor(args.workers) as pool:
        for name, scenario, out in pool.map(job, jobs):
            results[name][scenario] = out
            shown = " ".join(f"{out.get(f'ever_shown_by_week_{k}', 0) * 100:.1f}" for k in WEEKS)
            big = out["big_effect_by_56"]
            print(
                f"{name:14s} {scenario:13s} shown by wk 8/12/26/52: {shown}"
                f"  big@56 {'' if big is None else f'{big * 100:.1f}'}  cov56 {out['coverage_night_56'] * 100:.1f}"
                f"  ben {out['benefit']:.2f}  chg/wk {out['changes_per_week']:.2f}",
                flush=True,
            )
    report = {"people": args.people, "nights": args.nights, "seed": args.seed, "seconds": round(time.time() - started), "variants": results}
    Path(args.out).write_text(json.dumps(report, indent=1) + "\n")


if __name__ == "__main__":
    main()
