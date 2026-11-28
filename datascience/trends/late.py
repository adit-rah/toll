"""How often Health's late nights change a week's line after Monday noon (#173).

    uv run python -m trends.late --people 2000 --out reports/trends-late.json

The line is worked out from the nights each time it is read, never stored (D108). Health's sleep for
the judged week's last nights can reach the night log after Monday noon (D92's `rev` correction, made
when the app opens after the watch has synced), and the line can then change once. For each judged
Monday, this compares the line as it reads with the week's last night (or last three) not in yet with
the line once they are, and says what a reader would see change:
- **appears**: no line at noon (the week had too few nights), a line later;
- **way**: "About the same" against "earlier" or "later", or the other way round;
- **minutes**: the same way, a different number of minutes (five-minute steps, as the copy says it).
`looks` counts the judged Mondays where either reading shows a line.
"""

from __future__ import annotations

import argparse
import json
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from . import noise, study
from .rule import STEADY, Rule, centred, in_force, looks

RULE = Rule()
WEEKS = 12


def said(look, steady: bool):
    if look is None:
        return None
    if look.way == STEADY:
        return STEADY
    return look.way, None if steady else int(round(abs(look.d) / 5) * 5)


def line(series, now: int, steady: bool):
    if steady:
        found, _ = looks(
            series, now, RULE.floor_steady, True, RULE, center=lambda w: centred(w, RULE.centre, RULE.around),
            window=RULE.steady,
        )
    else:
        found, _ = looks(series, now, RULE.floor_minutes, True, RULE)
    return in_force(found, now)


def judge(job: tuple) -> tuple:
    name, scenario, people, seed, late = job
    values, _, starts = study.scenario_nights(noise.GRID[name], scenario, people, WEEKS, seed)
    out = {}
    for steady in (False, True):
        cell = {"looks": 0, "appears": 0, "way": 0, "minutes": 0, "people_changed": 0}
        for p in range(people):
            start = int(starts[p])
            series = study.series_of(values[p], start)
            changed = False
            for monday in range(start - start % 7 + 7, start + 7 * WEEKS + 1, 7):
                gone = {n for n, _ in series if monday - late <= n < monday}
                if not gone:
                    continue
                full = said(line(series, monday, steady), steady)
                noon = said(line([x for x in series if x[0] not in gone], monday, steady), steady)
                if full is None and noon is None:
                    continue
                cell["looks"] += 1
                if full == noon:
                    continue
                changed = True
                if noon is None:
                    cell["appears"] += 1
                elif STEADY in (noon, full) or noon[0] != full[0]:
                    cell["way"] += 1
                else:
                    cell["minutes"] += 1
            cell["people_changed"] += changed
        out["steady" if steady else "level"] = {k: v / (people if k == "people_changed" else 1) for k, v in cell.items()}
    return name, scenario, late, out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=2000)
    ap.add_argument("--seed", type=int, default=173)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    jobs = [
        (name, scenario, args.people, args.seed + 10 * i + j, late)
        for i, name in enumerate(noise.GRID)
        for j, scenario in enumerate(("still", "shift-30-early", "wander"))
        for late in (1, 3)
    ]
    with ProcessPoolExecutor() as pool:
        rows = list(pool.map(judge, jobs))
    out: dict = {"people": args.people, "seed": args.seed, "weeks": WEEKS, "profiles": {}}
    for name, scenario, late, cell in rows:
        out["profiles"].setdefault(name, {}).setdefault(scenario, {})[f"last_{late}"] = cell
    Path(args.out).write_text(json.dumps(out, indent=1, sort_keys=True))
    print(args.out)


if __name__ == "__main__":
    main()
