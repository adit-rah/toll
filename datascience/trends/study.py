"""How often Your sleep's trend lines claim a change that isn't there, and how often they catch one that is.

    uv run python -m trends.study sweep --out reports/trends-sweep.json
    uv run python -m trends.study final --people 4000 --out reports/trends-final.json
    uv run python -m trends.study final --profiles private/profiles.json --out private/trends.json

Each person starts on a random weekday and is judged as the phone judges them (`trends.rule`). The
scenarios, per noise profile (`trends.noise`):
- **still**: the nights' noise and nothing else. The level never moves: the 5% mark.
- **shuffled**: the profile's nights with its wander, put in a random order (the replay's null: the
  moves of the level become night noise and nothing changes over time). Also held to 5%.
- **wander**: the level moves as the profile says. A change against the first nights is then a true
  description; the study counts the claims made the wrong way, or larger than the level moved.
- **shift 30 / 60**: still, then a real step earlier after the first week (or from week 6).
- **differ**: still, then a step of the simulator's "differ" effect (N(8, 15) minutes per 30 minutes
  of earlier lock, D97's growth of 30 minutes) from week 3.
`today` is D104's rule (means, Welch's errors, z 2.2, judged every night) on the same nights.
"""

from __future__ import annotations

import argparse
import json
import math
from concurrent.futures import ProcessPoolExecutor
from dataclasses import asdict, replace
from pathlib import Path

import numpy as np

from . import noise
from .rule import STEADY, Rule, distances, looks, median

WEEKS = (12, 26)
SHIFT_FROM = {"early": 7, "week6": 35}


def series_of(values: np.ndarray, start: int) -> list[tuple[int, float]]:
    return [(start + i, float(v)) for i, v in enumerate(values) if not math.isnan(v)]


def person_looks(series, start: int, weeks: int, rule: Rule, steady: bool):
    now = start + 7 * weeks  # the morning after the last night: its Monday judges the last week
    if steady:
        found, _ = looks(series, now, rule.floor_steady, True, rule, center=distances, window=rule.steady)
    else:
        found, _ = looks(series, now, rule.floor_minutes, True, rule)
    return found


def today_rule(series, start: int, weeks: int, steady: bool) -> list[tuple[int, str, float]]:
    """D104's rule, judged every night: (night, way, d)."""
    out = []
    base = 14 if steady else 7
    ordered = sorted(series)
    first = ordered[:base]
    if len(first) < base:
        return out
    end = first[-1][0]
    then = [v for _, v in first]
    if steady:
        then = distances(then)
    for anchor in range(end + 1, start + 7 * weeks):
        later = [v for n, v in ordered if anchor - base < n <= anchor and n > end]
        if len(later) < (10 if steady else 5):
            continue
        if steady:
            later = distances(later)
        d = float(np.mean(later) - np.mean(then))
        se = math.sqrt(np.var(then, ddof=1) / len(then) + np.var(later, ddof=1) / len(later))
        floor = 10.0 if steady else 15.0
        claim = abs(d) >= floor and abs(d) >= 2.2 * se
        out.append((anchor, ("toward" if d < 0 else "away") if claim else STEADY, d))
    return out


def scenario_nights(profile: noise.Profile, scenario: str, people: int, weeks: int, seed: int):
    """(values, latent level, start days) for every person."""
    gen = np.random.default_rng(seed)
    if scenario == "shuffled":
        values, level = noise.nights(profile, people, weeks, gen, shuffle=True)
    elif scenario == "wander":
        values, level = noise.nights(profile, people, weeks, gen)
    else:
        values, level = noise.nights(profile.still(), people, weeks, gen)
    if scenario.startswith("shift") or scenario == "differ":
        if scenario == "differ":
            size = -gen.normal(8.0, 15.0, people)
            frm = 14
        else:
            _, amount, when = scenario.split("-")
            size = np.full(people, -float(amount))
            frm = SHIFT_FROM[when]
        step = np.zeros_like(values)
        step[:, frm:] = size[:, None]
        values = values + step
        level = level + step
    if scenario == "steadier":
        # Half the night's noise from week 3: really steadier.
        calm = noise.night_noise(replace(profile.still(), core=profile.core / 2, outlier=profile.outlier / 2), values.shape, gen)
        values = np.where(np.arange(values.shape[1]) >= 14, calm + np.where(np.isnan(values), np.nan, 0.0), values)
    starts = gen.integers(0, 7, people)
    return values, level, starts


def judge(job: tuple) -> dict:
    """One profile, one scenario, one rule: the share of people with each outcome by each week."""
    name, profile, scenario, rule, people, seed, with_today = job
    weeks = max(WEEKS)
    values, level, starts = scenario_nights(noise.Profile(**profile), scenario, people, weeks, seed)
    rule = Rule(**rule)
    out: dict = {"profile": name, "scenario": scenario}
    for steady in (False, True):
        floor = rule.floor_steady if steady else rule.floor_minutes
        ever = {w: 0 for w in WEEKS}
        right = {w: 0 for w in (4, 8, 12, 26)}
        wrong = over = flips = shown = judged = 0
        today_ever = today_days = today_false_days = 0
        for p in range(people):
            start = int(starts[p])
            s = series_of(values[p], start)
            found = person_looks(s, start, weeks, rule, steady)
            prev = None
            first_claim = first_right = None
            was_wrong = was_over = False
            for look in found:
                week = (look.monday - start) // 7
                truth = latent(level[p], start, look.monday, rule, steady, scenario)
                if look.way != STEADY:
                    first_claim = week if first_claim is None else first_claim
                    if truth * look.d > 0 and first_right is None:
                        first_right = week
                    if week <= 12 and not math.isnan(truth):
                        was_wrong |= truth * look.d <= 0
                        was_over |= truth * look.d > 0 and abs(truth) < floor / 2
                if week <= 12:
                    judged += 1
                    shown += look.way != STEADY
                    flips += prev is not None and prev != look.way
                prev = look.way
            for w in WEEKS:
                ever[w] += first_claim is not None and first_claim <= w
            for w in right:
                right[w] += first_right is not None and first_right <= w
            wrong += was_wrong
            over += was_over
            if with_today:
                days = today_rule(s, start, 12, steady)
                false_days = sum(1 for _, w, _ in days if w != STEADY)
                today_days += len(days)
                today_false_days += false_days
                today_ever += false_days > 0
        cell = {
            **{f"ever_claim_by_{w}": ever[w] / people for w in WEEKS},
            **{f"right_by_{w}": right[w] / people for w in right},
            "wrong_way_by_12": wrong / people,
            "overstated_by_12": over / people,
            "flips_per_person_12": flips / people,
            "share_of_weeks_claimed_12": shown / max(1, judged),
        }
        if with_today:
            cell["today_ever_by_12"] = today_ever / people
            cell["today_share_of_days"] = today_false_days / max(1, today_days)
        out["steady" if steady else "level"] = cell
    return out


def latent(level: np.ndarray, start: int, monday: int, rule: Rule, steady: bool, scenario: str) -> float:
    """How far the truth moved between the first nights and the judged nights: a level's minutes; for
    How steady, −1 once the judged nights are all steadier, 0 when nothing changed, NaN when the level
    wanders (its spread over two weeks then moves too, and there is no plain truth to hold it to)."""
    i = monday - start
    if steady:
        if scenario == "steadier":
            return -1.0 if i - rule.steady >= 14 else 0.0
        return float("nan") if scenario == "wander" else 0.0
    first = level[: rule.baseline]
    week = level[max(0, i - 7) : i]
    return float(week.mean() - first.mean()) if len(week) else 0.0


SCENARIOS = ["still", "shuffled", "wander", "shift-30-early", "shift-60-early", "shift-30-week6", "shift-60-week6", "differ", "steadier"]


def run(profiles: dict, rules: dict, people: int, seed: int, scenarios=SCENARIOS, with_today=True) -> dict:
    jobs = []
    for rname, rule in rules.items():
        for i, (pname, profile) in enumerate(profiles.items()):
            for j, sc in enumerate(scenarios):
                jobs.append((pname, asdict(profile), sc, asdict(rule), people, seed + 100 * i + j, with_today))
    with ProcessPoolExecutor() as pool:
        results = list(pool.map(judge, jobs))
    out: dict = {}
    n = len(profiles) * len(scenarios)
    for k, rname in enumerate(rules):
        cell = out.setdefault(rname, {"rule": asdict(rules[rname])})
        for r in results[k * n : (k + 1) * n]:
            cell.setdefault(r["profile"], {})[r["scenario"]] = {"level": r["level"], "steady": r["steady"]}
    return out


def load_profiles(path: str | None) -> dict[str, noise.Profile]:
    if path is None:
        return dict(noise.GRID)
    raw = json.loads(Path(path).read_text())
    return {name: noise.Profile(**row["profile"]) for name, row in raw.items()}


SWEEP: dict[str, Rule] = {
    f"b{b}-{spread}-m{miss}-p{power}": Rule(baseline=b, spread=spread, miss=miss, power=power)
    for b in (7, 14)
    for spread in ("winsor", "mad")
    for miss in (0.01, 0.02, 0.04)
    for power in (0.5, 1.0, 2.0)
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["sweep", "final"])
    ap.add_argument("--people", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=165)
    ap.add_argument("--profiles")
    ap.add_argument("--only", help="comma-separated rule names from the sweep")
    ap.add_argument("--scenarios", help="comma-separated")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    profiles = load_profiles(args.profiles)
    if args.mode == "final":
        rules = {"chosen": Rule()}
    else:
        rules = SWEEP if not args.only else {k: SWEEP[k] for k in args.only.split(",")}
    scenarios = args.scenarios.split(",") if args.scenarios else SCENARIOS
    out = {
        "people": args.people,
        "seed": args.seed,
        "profiles": {k: asdict(v) for k, v in profiles.items()},
        "rules": run(profiles, rules, args.people, args.seed, scenarios, with_today=args.mode == "final"),
    }
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(out, indent=1, sort_keys=True))
    print(args.out)


if __name__ == "__main__":
    main()
