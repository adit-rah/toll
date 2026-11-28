"""Writes the trend rule's parity fixtures (#165) for TollCore's tests.

    uv run python -m trends.fixtures

Named cases for each part of the rule, then random people. TollCore's `TrendParityTests` replays every
case through `SleepTrends`' reader and must give the same values, looks and ways; `tests/test_trends.py`
checks the committed copies are what this writes. Day 0 is a Monday night (the Swift side reads it as
2 November 2026); `now` is the night key of the moment the screen is read.
"""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path

import numpy as np

from .rule import Rule, level_measure, locked_measure, spread_measure

HERE = Path(__file__).resolve().parent
OUT = HERE / "fixtures" / "trends.json"
SWIFT = HERE.parents[1] / "ios/Packages/TollCore/Tests/TollCoreTests/Fixtures/trends/trends.json"

WOBBLE = [-10, 10, -10, 10, -10, 10, 0]


def weeks(levels: list[float], wobble=WOBBLE, start: int = 0) -> list[list[float]]:
    """Seven nights a level, each `wobble` either side, from `start`."""
    out = []
    for w, level in enumerate(levels):
        for i in range(7):
            out.append([start + 7 * w + i, float(level + wobble[i])])
    return out


def wild(nights: list[list[float]], day: int, by: float) -> list[list[float]]:
    return [[d, v + by] if d == day else [d, v] for d, v in nights]


def named() -> list[dict]:
    steady_spread = [[d, 700.0 + (40 if d % 2 else -40) * (1 if d < 14 else 0.2)] for d in range(42)]
    return [
        {"name": "a 30 min earlier week is said", "kind": "level", "nights": weeks([720, 690]), "now": 14},
        {"name": "held all week until the next Monday", "kind": "level", "nights": weeks([720, 690, 690]), "now": 20},
        {"name": "before the first Monday noon there is no line", "kind": "level", "nights": weeks([720, 690, 690]), "now": 13},
        {"name": "one wild night doesn't make a change", "kind": "level", "nights": wild(weeks([720, 720]), 10, -300), "now": 14},
        {"name": "one wild night doesn't hide one", "kind": "level", "nights": wild(weeks([720, 680]), 10, 300), "now": 14},
        {"name": "under the floor is the same", "kind": "level", "nights": weeks([720, 710], [0] * 7), "now": 14},
        {"name": "noisy nights hide a small change", "kind": "level", "nights": weeks([720, 695], [-60, 60, -60, 60, -60, 60, 0]), "now": 14},
        {
            "name": "a change said is kept at the first look's test",
            "kind": "level",
            "nights": weeks([720, 690, 690, 690, 690, 690, 698], [-8, 8, -8, 8, -8, 8, 0]),
            "now": 49,
        },
        {"name": "a judged week with four nights says nothing", "kind": "level", "nights": weeks([720, 690])[:11], "now": 14},
        {"name": "first nights ending mid-week", "kind": "level", "nights": weeks([720, 690, 690], start=3), "now": 21},
        {"name": "fewer reaches", "kind": "level", "floor": 0.5, "nights": weeks([4, 1], [0, 1, 0, 1, 0, 0, 0]), "now": 14},
        {"name": "reaches that tie at nought", "kind": "level", "floor": 0.5, "nights": weeks([0, 1], [0] * 7), "now": 14},
        {"name": "more time asleep", "kind": "level", "lower": False, "nights": weeks([400, 440]), "now": 14},
        {"name": "steadier over two weeks", "kind": "steady", "nights": steady_spread, "now": 28},
        {"name": "steadier, a week later", "kind": "steady", "nights": steady_spread, "now": 35},
        {"name": "too few for how steady", "kind": "steady", "nights": steady_spread[:6], "now": 7},
        {
            "name": "calmer since the first week: its own noise stands",
            "kind": "level",
            "nights": weeks([720], [-20, 20, -20, 20, -20, 20, 0]) + weeks([690] * 6, [-3, 3, -3, 3, -3, 3, 0], start=7),
            "now": 49,
        },
        {"name": "a usual time that moved in the first nights isn't steadier", "kind": "steady", "nights": weeks([720, 660, 660, 660, 660]), "now": 35},
        {"name": "a usual time that moves week to week isn't less steady", "kind": "steady", "nights": weeks([700, 700, 760, 700, 760, 700]), "now": 42},
        {"name": "nights locked: one more", "kind": "locked", "nights": [[d, 0.0 if d in (2, 4, 5) else 1.0] for d in range(14)], "now": 14},
    ]


def random_cases(count: int, seed: int) -> list[dict]:
    gen = np.random.default_rng(seed)
    cases = []
    for i in range(count):
        kind = ["level", "level", "steady", "locked"][i % 4]
        start = int(gen.integers(0, 7))
        n = int(gen.integers(3, 120))
        core = float(gen.choice([10, 25, 60]))
        values = 700 + gen.normal(0, core, n)
        wild_nights = gen.random(n) < float(gen.choice([0, 0.1, 0.3]))
        values = np.where(wild_nights, values + gen.normal(0, 150, n), values)
        shift_at = int(gen.integers(0, n))
        values[shift_at:] += float(gen.choice([0, -20, -45, 30]))
        if kind == "steady":
            values[shift_at:] = 700 + (values[shift_at:] - 700) * float(gen.choice([0.3, 1, 2]))
        if kind == "locked":
            values = (gen.random(n) < float(gen.choice([0.5, 0.9]))).astype(float)
        keep = gen.random(n) >= float(gen.choice([0, 0.1, 0.3]))
        nights = [[start + d, round(float(v), 1)] for d, v in enumerate(values) if keep[d]]
        now = start + int(gen.integers(2, n + 10))
        cases.append({"name": f"random {i}", "kind": kind, "nights": nights, "now": now})
    return cases


def expected(case: dict, rule: Rule) -> dict | None:
    series = [(int(d), float(v)) for d, v in case["nights"]]
    if case["kind"] == "steady":
        return spread_measure(series, case["now"], rule)
    if case["kind"] == "locked":
        return locked_measure(series, case["now"], rule)
    return level_measure(series, case["now"], case["floor"], case["lower"], rule)


def build() -> dict:
    rule = Rule()
    cases = []
    for case in named() + random_cases(400, 165):
        case.setdefault("floor", rule.floor_minutes)
        case.setdefault("lower", True)
        case["expected"] = expected(case, rule)
        cases.append(case)
    return {"rule": asdict(rule), "cases": cases}


def text() -> str:
    """One case a line, so a change to the rule reads as a short diff."""
    built = build()
    cases = ",\n".join(json.dumps(case, sort_keys=True) for case in built["cases"])
    return '{"rule": ' + json.dumps(built["rule"], sort_keys=True) + ',\n"cases": [\n' + cases + "\n]}\n"


def main() -> None:
    body = text()
    for path in (OUT, SWIFT):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)
        print(path)


if __name__ == "__main__":
    main()
