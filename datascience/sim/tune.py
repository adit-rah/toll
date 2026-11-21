"""Tries the starting values the spec asks to tune and writes down every result.

    uv run python -m sim.tune --people 1000

Writes reports/tuning.json; reports/tuning.md is written by hand from it, with the reasoning.
"""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

from dusk_model.artifact import Params
from export import v0

from .criteria import evaluate

TRIALS = {
    "v0 as specced (σ 30, effect sd 15, floor 0.10, clip 90, zero test 90%)": {"zero": 0.9},
    "σ 35": {"noise_sd": 35.0, "zero": 0.9},
    "σ 40": {"noise_sd": 40.0, "zero": 0.9},
    "effect prior sd 10": {"prior.sd1": 10.0, "zero": 0.9},
    "effect prior sd 20": {"prior.sd1": 20.0, "zero": 0.9},
    "floor 0.20": {"min_prob": 0.2, "zero": 0.9},
    "floor 0.33 (uniform)": {"min_prob": 1 / 3, "zero": 0.9},
    "clip 60": {"clip": 60.0, "zero": 0.9},
    "clip 45": {"clip": 45.0, "zero": 0.9},
    "forgetting 0.98": {"forgetting": 0.98, "zero": 0.9},
    "zero test 95%": {"zero": 0.95},
    "zero test 98%": {"zero": 0.98},
    "zero test 99%": {"zero": 0.99},
    "σ 32.5, zero test 98%": {"noise_sd": 32.5, "zero": 0.98},
    "σ 32.5, effect sd 20, zero test 98%": {"noise_sd": 32.5, "prior.sd1": 20.0, "zero": 0.98},
    "σ 35, zero test 95%": {"noise_sd": 35.0, "zero": 0.95},
    "σ 32.5, forgetting 0.99, zero test 98%": {"noise_sd": 32.5, "forgetting": 0.99, "zero": 0.98},
    "σ 30, effect sd 20, forgetting 0.99, zero test 98%": {"prior.sd1": 20.0, "forgetting": 0.99, "zero": 0.98},
}


def variant(changes: dict, draws: int) -> Params:
    a = copy.deepcopy(v0.artifact())
    a["policy"]["prob_draws"] = draws
    for key, value in changes.items():
        if key == "noise_sd":
            a["noise_sd"] = value
        elif key == "prior.sd1":
            a["prior"]["cov_diag_sd"][1] = value
        elif key == "min_prob":
            a["policy"]["min_prob"] = value
        elif key == "clip":
            a["usable_night"]["residual_clip_min"] = value
        elif key == "forgetting":
            a["forgetting"] = value
        elif key == "interval":
            a["insight"]["interval"] = value
        elif key == "zero":
            a["insight"]["zero_test_interval"] = value
    return Params.from_artifact(a)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=1000)
    ap.add_argument("--draws", type=int, default=300)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--out", default="reports/tuning.json")
    args = ap.parse_args()
    results = {}
    for name, changes in TRIALS.items():
        out = evaluate(variant(changes, args.draws), args.people, args.seed, safety_people=0)
        s = out["scenarios"]
        results[name] = {
            "changes": changes,
            "checks": {c["check"]: c["passed"] for c in out["checks"]},
            "coverage_end": {k: round(v["coverage_end"], 3) for k, v in s.items()},
            "fade_coverage_end": round(out["fade"]["coverage_end"], 3),
            "median_first_insight_differ": s["differ"]["median_first_insight_night"],
            "shown_by_28_differ": round(s["differ"]["shown_by_night"][27], 3),
            "ever_shown_null": round(s["null"]["ever_shown"], 3),
            "thompson_minus_fixed": {k: round(v["thompson_minus_fixed"], 2) for k, v in s.items()},
        }
        print(name, json.dumps(results[name]), flush=True)
    Path(args.out).write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
