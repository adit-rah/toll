"""The simulator's pass criteria (model spec, section 6.4), as one JSON report.

    uv run python -m sim.criteria --people 2000 --safety-people 10000 --out reports/criteria.json

Checks are proposals agreed with the founders, not facts; the report keeps the series behind each one so
the figures (reports/figures.py) and the tuning log can be redrawn from it.
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np

from dusk_model import artifact
from dusk_model.artifact import Params
from dusk_model.night import features
from dusk_model.timing import policy_name
from export.versions import SHIPPED

from .records import records
from .run import ACTIONS, NIGHTS, World, run, world
from .scenarios import SCENARIOS

LONG_NIGHTS = 364  # a year: the insight is checked every night for as long as Dusk is used (#117)
# The null for a year, alone and with the person's usual time moving (#154, `sim.wander`).
LONG_SCENARIOS = ("null", "null+wander", "null+drift", "null+wide", "null+slow")


def first_insight_night(shown: np.ndarray) -> np.ndarray:
    """1-based night of each person's first insight; inf if never."""
    return np.where(shown.any(axis=1), shown.argmax(axis=1) + 1.0, np.inf)


def covered(r, night: int) -> np.ndarray:
    return (r.low[:, night] <= r.truth[:, night]) & (r.truth[:, night] <= r.high[:, night])


def summarize(scenario: str, w: World, ts, fixed) -> dict:
    home = ts.home
    weekly = []
    for week in range(NIGHTS // 7):
        nights = slice(week * 7, week * 7 + 7)
        h = home[:, nights]
        weekly.append(float((ts.true_onset[:, nights][h] - fixed.true_onset[:, nights][h]).mean()))
    first = first_insight_night(ts.shown)
    effect = np.abs(w.people.truth[:, 1])
    bands = [(0, 5), (5, 10), (10, 15), (15, 20), (20, 30), (30, np.inf)]
    by_effect = []
    for lo, hi in bands:
        m = (effect >= lo) & (effect < hi)
        if m.sum() >= 20:
            by_effect.append(
                {
                    "effect_low": lo,
                    "effect_high": None if np.isinf(hi) else hi,
                    "people": int(m.sum()),
                    "median_first_night": None if np.isinf(np.median(first[m])) else float(np.median(first[m])),
                    "shown_by_28": float((first[m] <= 28).mean()),
                    "shown_by_56": float((first[m] <= 56).mean()),
                }
            )
    wrong_sign = ts.shown & (np.sign(ts.estimate) != np.sign(ts.truth)) & (ts.truth != 0)
    return {
        "scenario": scenario,
        "people": int(w.people.count),
        "coverage_by_week": [float(covered(ts, 7 * k + 6).mean()) for k in range(NIGHTS // 7)],
        "coverage_end": float(covered(ts, NIGHTS - 1).mean()),
        "shown_by_night": [float(ts.shown[:, : t + 1].any(axis=1).mean()) for t in range(NIGHTS)],
        "median_first_insight_night": None if np.isinf(np.median(first)) else float(np.median(first)),
        "ever_shown": float(ts.shown.any(axis=1).mean()),
        "ever_shown_wrong_sign": float(wrong_sign.any(axis=1).mean()),
        "first_insight_by_effect": by_effect,
        "mean_onset_thompson": float(ts.true_onset[home].mean()),
        "mean_onset_fixed": float(fixed.true_onset[home].mean()),
        "thompson_minus_fixed": float((ts.true_onset[home] - fixed.true_onset[home]).mean()),
        "thompson_minus_fixed_by_week": weekly,
        "share_of_starts": {str(a): float((ts.offset[home] == a).mean()) for a in ACTIONS},
        "usable_night_share": float(ts.usable.mean()),
        "changes_per_week": changes_per_week(ts),
        "settled_at_end": float(ts.settled[:, -1].mean()),
    }


def changes_per_week(r) -> float:
    """Nights a week the start differs from the last night the block ran (D66: about 0.5)."""
    count, nights = r.home.shape
    last, changes = np.zeros(count), np.zeros(count)
    for t in range(nights):
        changes += r.home[:, t] & (r.offset[:, t] != last)
        last = np.where(r.home[:, t], r.offset[:, t], last)
    return float(changes.mean() / (nights / 7))


def long_run(params: Params, people: int, seed: int, nights: int = LONG_NIGHTS, scenario: str = "null") -> dict:
    """A null scenario for a year: the share ever shown an insight, week by week."""
    from .wander import make_world  # sim.wander reads this module through sim.dampen_sweep

    w = make_world(scenario, people, seed, nights=nights)
    r = run(w, params, "thompson", seed)
    first = first_insight_night(r.shown)
    return {
        "scenario": scenario,
        "people": people,
        "nights": nights,
        "ever_shown_by_week": [float((first <= 7 * (k + 1)).mean()) for k in range(nights // 7)],
        "ever_shown": float(np.isfinite(first).mean()),
    }


def safety(params: Params, people: int, seed: int, version: str) -> dict:
    """Mixed scenarios: every start offset allowed for that person, and the wake time never moves."""
    per = people // len(SCENARIOS)
    nights = outside = moved = skipped_mismatch = 0
    min_prob = 1.0
    for i, scenario in enumerate(SCENARIOS):
        w = world(scenario, per, seed + 100 + i)
        r = run(w, params, "thompson", seed + 100 + i)
        allowed = w.people.allowed
        for k, a in enumerate(ACTIONS):
            outside += int(((r.offset == a) & r.home & ~allowed[:, k][:, None]).sum())
        outside += int((r.home & ~np.isin(r.offset, ACTIONS)).sum())
        several = allowed.sum(axis=1) > 1
        min_prob = min(min_prob, float(r.prob[several][r.home[several]].min()))
        for p in range(per):
            for t, rec in enumerate(records(w, r, p, version, policy_name(params), seed)):
                if rec["block_start"] is None:
                    continue
                nights += 1
                moved += rec["block_end"] != rec["planned_wake"]
                f = features(rec, params)
                skipped_mismatch += f.usable != bool(r.usable[p, t])
    return {
        "people": per * len(SCENARIOS),
        "block_nights": nights,
        "offsets_outside_allowed": outside,
        "wake_time_moved": moved,
        "min_logged_prob_with_choice": min_prob,
        "record_vs_sim_usable_mismatches": skipped_mismatch,
    }


def evaluate(
    params: Params, people: int, seed: int, safety_people: int, fade: bool = True, long_people: int = 0
) -> dict:
    out = {"model_version": params.version, "people_per_scenario": people, "seed": seed, "scenarios": {}}
    for i, scenario in enumerate(SCENARIOS):
        w = world(scenario, people, seed + i)
        out["scenarios"][scenario] = summarize(scenario, w, run(w, params, "thompson", seed + i), run(w, params, "fixed"))
    if fade:
        w = world("differ", people, seed + 50, fade=True)
        out["fade"] = summarize("differ+fade", w, run(w, params, "thompson", seed + 50), run(w, params, "fixed"))
    if safety_people:
        out["safety"] = safety(params, safety_people, seed, params.version)
    if long_people:
        out["long_run"] = long_run(params, long_people, seed + 200)
        out["long_runs"] = {
            s: long_run(params, long_people, seed + 200 + i, scenario=s) for i, s in enumerate(LONG_SCENARIOS) if s != "null"
        }
    out["checks"] = checks(out)
    return out


def checks(out: dict) -> list[dict]:
    s = out["scenarios"]
    cov = {k: v["coverage_end"] for k, v in s.items()}
    rows = [
        ("Ranges are honest", "all scenarios", "90% ranges contain the true value in 85 to 95% of people",
         all(0.85 <= c <= 0.95 for c in cov.values()), cov),
        ("Learns fast enough", "differ", "median person gets a usable insight by night 28",
         (s["differ"]["median_first_insight_night"] or 99) <= 28, s["differ"]["median_first_insight_night"]),
        ("Helps when people differ", "differ", "sleep earlier on average than always using the plan",
         s["differ"]["thompson_minus_fixed"] < 0, s["differ"]["thompson_minus_fixed"]),
        ("Does little harm when they don't", "same", "at most 5 minutes a night worse than the plan",
         s["same"]["thompson_minus_fixed"] <= 5, s["same"]["thompson_minus_fixed"]),
        ("No false insights", "null", "a non-zero effect shown to at most 5% of people",
         s["null"]["ever_shown"] <= 0.05, s["null"]["ever_shown"]),
    ]
    big = [r for r in s["differ"]["first_insight_by_effect"] if r["effect_low"] >= 15]
    big_share = sum(r["shown_by_56"] * r["people"] for r in big) / max(1, sum(r["people"] for r in big))
    rows.append(("Learns fast enough (decisions D66)", "differ",
                 "at least half of people with a true effect of 15 min or more get an insight by night 56",
                 big_share >= 0.5, round(big_share, 3)))
    if "long_run" in out:
        lr = out["long_run"]
        rows.append(("No false insights over a year (#117)", f"null, {lr['nights']} nights",
                     "a non-zero effect ever shown to at most 5% of people",
                     lr["ever_shown"] <= 0.05, lr["ever_shown"]))
    for scenario, lr in out.get("long_runs", {}).items():
        rows.append((f"No false insights over a year, {scenario.split('+')[1]} (#154)", f"{scenario}, {lr['nights']} nights",
                     "a non-zero effect ever shown to at most 5% of people",
                     lr["ever_shown"] <= 0.05, lr["ever_shown"]))
    if "safety" in out:
        sf = out["safety"]
        rows.append(("Never unsafe", f"{sf['people']} people x 8 weeks",
                     "zero offsets outside the allowed actions; the wake time never moves",
                     sf["offsets_outside_allowed"] == 0 and sf["wake_time_moved"] == 0,
                     {"outside": sf["offsets_outside_allowed"], "wake_moved": sf["wake_time_moved"]}))
    return [{"check": c, "harness": h, "pass_if": p, "passed": bool(ok), "value": v} for c, h, p, ok, v in rows]


def recheck(path: str) -> None:
    """Recomputes the checks of a saved report, e.g. after a check is added."""
    out = json.loads(Path(path).read_text())
    out["checks"] = checks(out)
    Path(path).write_text(json.dumps(out, indent=2) + "\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifact", default=f"artifacts/{SHIPPED.VERSION}.json")
    ap.add_argument("--people", type=int, default=2000)
    ap.add_argument("--safety-people", type=int, default=10_000)
    ap.add_argument("--long-people", type=int, default=2000, help="null people run for a year (#117); 0 skips")
    ap.add_argument("--seed", type=int, default=20261120)
    ap.add_argument("--out", default="reports/criteria.json")
    ap.add_argument("--strict", action="store_true", help="exit 1 if a check fails that is not waived")
    ap.add_argument(
        "--waive",
        action="append",
        # The spec's, replaced by D66's learning mark (decisions D53, D66); and D66's, which v2 gives up
        # for ranges that stay honest when the usual time moves (#154, reports/longrun.md section 7),
        # until the founders set a new one.
        default=["Learns fast enough", "Learns fast enough (decisions D66)"],
        help="a check reported but not enforced",
    )
    args = ap.parse_args()
    params = Params.from_artifact(artifact.load(Path(args.artifact)))
    started = time.time()
    out = evaluate(params, args.people, args.seed, args.safety_people, long_people=args.long_people)
    out["seconds"] = round(time.time() - started, 1)
    Path(args.out).write_text(json.dumps(out, indent=2) + "\n")
    failed = []
    for row in out["checks"]:
        waived = row["check"] in args.waive and not row["passed"]
        print(f"{'PASS' if row['passed'] else 'WAIVED' if waived else 'FAIL'}  {row['check']}: {row['value']}")
        if not row["passed"] and not waived:
            failed.append(row["check"])
    if args.strict and failed:
        raise SystemExit(f"failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
