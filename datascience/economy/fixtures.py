"""Writes the buffer suggestion's parity fixtures (#145) for TollCore's tests.

    uv run python -m economy.fixtures

Named cases for each branch of the rule, then random weeks. TollCore's `BufferSuggestionTests` replays
every case and must give the same targets; `tests/test_economy.py` checks the committed copies are what
this writes.
"""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path

import numpy as np

from .suggest import HARD, HOLD, OFF, SMOOTH, Rule, Week, late_onset, suggest

HERE = Path(__file__).resolve().parent
OUT = HERE / "fixtures" / "buffer-suggestion.json"
SWIFT = HERE.parents[1] / "ios/Packages/TollCore/Tests/TollCoreTests/Fixtures/buffers/suggestion.json"


def w(minutes: int, verdict: str, pauses: int | None = None) -> Week:
    if pauses is None:
        pauses = {SMOOTH: 0, HARD: 2, OFF: 0, HOLD: 0}[verdict]
    return Week(minutes, verdict, pauses)


def smooth_to(top: int, start: int = 30) -> list[Week]:
    return [w(m, SMOOTH) for m in range(start, top + 1, 15)]


LATE = [35] * 14
NAMED: list[tuple[str, list[Week], list[Week], list[int]]] = [
    ("no weeks: the baseline", [], [], []),
    ("three judged weeks are too few", smooth_to(60), [w(15, SMOOTH), w(30, SMOOTH)], LATE),
    ("holds don't count toward the four", smooth_to(60) + [w(60, HOLD)], [], []),
    ("smooth to 60: fitted at the baseline", smooth_to(60) + [w(60, SMOOTH)], [], []),
    (
        "hard at 60 twice: a step below",
        smooth_to(60) + [w(60, HARD), w(45, SMOOTH), w(45, SMOOTH), w(60, HARD)],
        [],
        [],
    ),
    ("one hard week at 60, none smooth there", smooth_to(60) + [w(60, HARD), w(45, SMOOTH)], [], []),
    (
        "an early bad week below a comfortable level is noise",
        [w(30, HARD), w(30, SMOOTH)] + smooth_to(60, 45) + [w(60, SMOOTH)],
        [],
        [],
    ),
    ("Screen Time off counts as hard", smooth_to(45) + [w(45, OFF), w(45, OFF), w(30, SMOOTH)], [], []),
    ("hard even at 30: never below 30", [w(30, HARD), w(30, HARD), w(30, OFF), w(30, HOLD), w(30, HARD)], [], []),
    ("sailing at 60 with Health's sign: 75", smooth_to(60) + [w(60, SMOOTH), w(60, SMOOTH)], [], LATE),
    ("sailing at 60 without the sign: 60", smooth_to(60) + [w(60, SMOOTH), w(60, SMOOTH)], [], [5] * 20),
    ("too few Health nights: no sign", smooth_to(60) + [w(60, SMOOTH), w(60, SMOOTH)], [], [35] * 13),
    ("a pause in the buffer: no raise", smooth_to(60) + [w(60, SMOOTH, 1), w(60, SMOOTH)], [], LATE),
    ("at 75, three more smooth: 90", smooth_to(60) + [w(75, SMOOTH)] * 3, [], LATE),
    ("at 90: never past 90", smooth_to(60) + [w(75, SMOOTH)] + [w(90, SMOOTH)] * 3, [], LATE),
    ("hard at 75: back to 60", smooth_to(60) + [w(60, SMOOTH)] * 2 + [w(75, HARD), w(60, SMOOTH)], [], LATE),
    ("a buffer of 0 isn't judged", [w(0, SMOOTH)] * 6, [w(0, HARD)] * 6, []),
    ("after: smooth at 30 stays 30", [], [w(15, SMOOTH), w(30, SMOOTH), w(30, SMOOTH), w(30, SMOOTH)], LATE),
    ("after: hard at 30 goes to 15", [], [w(15, SMOOTH), w(30, HARD), w(15, SMOOTH), w(30, HARD)], []),
    ("after: hard at 15 stays 15", [], [w(15, HARD)] * 4, []),
    (
        "only the last 12 weeks count",
        [w(60, HARD)] * 4 + smooth_to(60) + [w(60, SMOOTH)] * 9,
        [],
        [],
    ),
    ("the median of an even count", smooth_to(60) + [w(60, SMOOTH)] * 2, [], [10] * 7 + [30] * 7),
    ("the median just under", smooth_to(60) + [w(60, SMOOTH)] * 2, [], [10] * 7 + [29] * 7),
]


def random_cases(count: int, seed: int) -> list[tuple[str, list[Week], list[Week], list[int]]]:
    gen = np.random.default_rng(seed)
    verdicts = [SMOOTH, HARD, OFF, HOLD]
    cases = []
    for i in range(count):
        sides = []
        for levels in ((0, 15, 30, 45, 60, 75, 90), (0, 15, 30, 45)):
            weeks = []
            for _ in range(int(gen.integers(0, 16))):
                v = verdicts[int(gen.choice(4, p=[0.6, 0.2, 0.05, 0.15]))]
                pauses = int(gen.integers(2, 4)) if v == HARD else int(gen.integers(0, 2 if v != OFF else 4))
                weeks.append(Week(int(gen.choice(levels)), v, pauses))
            sides.append(weeks)
        late = [int(x) for x in gen.integers(-30, 90, size=int(gen.integers(0, 30)))]
        cases.append((f"random {i}", sides[0], sides[1], late))
    return cases


def build() -> dict:
    rule = Rule()
    cases = []
    for name, before, after, late in NAMED + random_cases(300, 145):
        cases.append(
            {
                "name": name,
                "before": [[x.minutes, x.verdict, x.pauses] for x in before],
                "after": [[x.minutes, x.verdict, x.pauses] for x in after],
                "late": late,
                "late_onset": late_onset(late, rule),
                "expected": suggest(before, after, late_onset(late, rule), rule),
            }
        )
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
