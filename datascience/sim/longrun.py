"""False insights and learning over a year of nights, for v1, v2 and the variants tuned for #117 and #154.

    uv run python -m sim.longrun --people 1000 --out reports/longrun-sweep.json
    uv run python -m sim.longrun --people 2000 --seed 20261127 --only v0,d66,v1 --out reports/longrun-final.json
    for s in 101 202 303 404 505 606; do uv run python -m sim.longrun --people 2000 --seed $s --only v1 \
      --scenarios null,differ --out seed$s.json; done
    uv run python -m sim.longrun --pool seed*.json --out reports/longrun-seeds.json

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
from export import v0, v1, v2

from .criteria import changes_per_week, first_insight_night
from .run import NIGHTS, Run, run
from .wander import make_world

YEAR = 364
WEEKS = (8, 12, 26, 52)
# Each scenario's seed is the run's seed plus its place here, so new ones go at the end (`sim.wander`).
SCENARIOS = [
    "null", "null+wander", "null+drift", "differ", "differ+wander", "differ+drift", "same",
    "null+wide", "null+slow", "differ+wide", "differ+slow",
]

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
    "v2": {},  # export/v2.py itself (#154)
}
WANDER_KEYS = {
    "w": "intercept_week_sd",
    "k": "noise_scale_prior_nights",
    "z": "zero_test_interval",
    "n": "zero_test_spend_after",
    "p": "zero_test_spend_power",
}


def wander_variant(name: str) -> dict:
    """#154's variants by name, on v1: "w10-k14-z96" lets the intercept wander 10 minutes a week,
    learns the noise's scale with 14 nights of 1, and uses a 96% zero test. `z` is in percent; `n`
    and `p` are the zero test's spending (`zero_test_spend_after`, `zero_test_spend_power`)."""
    over: dict = {}
    for part in name.split("-"):
        key, value = WANDER_KEYS[part[0]], float(part[1:])
        over[key] = value / 100.0 if part[0] == "z" else int(value) if part[0] == "n" else value
    return over


def artifact_for(name: str) -> dict:
    if name == "v2":
        return v2.artifact()
    over = VARIANTS[name] if name in VARIANTS else wander_variant(name)
    return v0.artifact() if over is None else v1.artifact(**over)


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


KEPT = ("ever_shown_by_week_8", "ever_shown_by_week_52", "big_effect_by_56", "coverage_night_56", "benefit")


def pool_runs(paths: list[str]) -> dict:
    """The main numbers of several runs side by side, and their mean, per variant and scenario."""
    runs = [json.loads(Path(p).read_text()) for p in paths]
    out: dict = {"runs": [{"seed": r["seed"], "people": r["people"], "nights": r["nights"]} for r in runs], "variants": {}}
    for run_ in runs:
        for name, variant in run_["variants"].items():
            for scenario, numbers in variant.items():
                if scenario == "artifact":
                    continue
                cell = out["variants"].setdefault(name, {}).setdefault(scenario, {k: [] for k in KEPT})
                for k in KEPT:
                    cell[k].append(numbers.get(k))
    for variant in out["variants"].values():
        for cell in variant.values():
            for k in KEPT:
                values = [v for v in cell[k] if v is not None]
                cell[f"{k}_mean"] = float(np.mean(values)) if values else None
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pool", nargs="+", help="runs to put side by side, instead of running")
    ap.add_argument("--people", type=int, default=1000)
    ap.add_argument("--nights", type=int, default=YEAR)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--only", default=",".join(VARIANTS))
    ap.add_argument("--scenarios", default=",".join(SCENARIOS))
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default="reports/longrun-sweep.json")
    args = ap.parse_args()
    if args.pool:
        Path(args.out).write_text(json.dumps(pool_runs(args.pool), indent=1) + "\n")
        return
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
