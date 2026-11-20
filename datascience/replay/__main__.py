"""Replays one person's nights and reports prediction error against the base.

    uv run python -m replay --health ~/Downloads/apple_health_export/export.xml --bedtime 23:00
    uv run python -m replay --records nights.jsonl      # the app's transition log export

The founders' own exports are the first real test (model spec, section 6.2). Nothing leaves the laptop.
"""

from __future__ import annotations

import argparse
import json
from datetime import time
from pathlib import Path

from dusk_model import artifact
from dusk_model.artifact import Params

from .evaluate import replay
from .health import records


def main() -> None:
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--health", type=Path, help="export.xml from the Health app")
    src.add_argument("--records", type=Path, help="night records, one JSON object per line")
    ap.add_argument("--bedtime", default="23:00", help="planned bedtime on weeknights (Health only)")
    ap.add_argument("--weekend-bedtime", default=None, help="Friday and Saturday (default: --bedtime)")
    ap.add_argument("--artifact", type=Path, default=Path("artifacts/sleep-model.v0.json"))
    ap.add_argument("--out", type=Path, default=None, help="write the full report here")
    args = ap.parse_args()
    params = Params.from_artifact(artifact.load(args.artifact))
    if args.health:
        weekday = time.fromisoformat(args.bedtime)
        weekend = time.fromisoformat(args.weekend_bedtime or args.bedtime)
        nights = records(args.health, weekday, weekend)
    else:
        nights = [json.loads(line) for line in args.records.read_text().splitlines() if line.strip()]
    report = replay(nights, params)
    if args.out:
        args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "rows"}, indent=2))


if __name__ == "__main__":
    main()
