"""Runs the fixtures through the Swift package's replay tool and records how far it is from Python.

    uv run python -m export.parity      # needs a Swift toolchain

Writes reports/parity.json, which the figures read. The Swift tests already enforce 1e-9; this keeps
the actual numbers so the report can show them.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT.parent / "ios" / "Packages" / "SleepModel"


def pairs(py: dict, sw: dict):
    for a, b in zip(py["steps"], sw["steps"]):
        yield "prob", a["choice"]["prob"], b["choice"]["prob"]
        for x, y in zip(a["state"]["precision"], b["state"]["precision"]):
            yield "precision", x, y
        for x, y in zip(a["state"]["b"], b["state"]["b"]):
            yield "b", x, y
        for key in ("scale_sum", "scale_cross", "scale_nights", "week_sum", "week_nights", "last_week_sum"):
            yield "scale", a["state"][key], b["state"][key]
        for p, q in zip(a["predictions"], b["predictions"]):
            yield "mean", p["mean"], q["mean"]
            yield "sd", p["sd"], q["sd"]
        for p, q in zip(a["insights"], b["insights"]):
            yield "insight", p["minutes"], q["minutes"]


def main() -> None:
    fixtures = (ROOT / "artifacts" / "fixtures.jsonl").read_text()
    result = subprocess.run(
        ["swift", "run", "-c", "release", "--package-path", str(PACKAGE), "sleep-model-replay"],
        input=fixtures, capture_output=True, text=True, check=True,
    )
    swift = {c["name"]: c for c in map(json.loads, result.stdout.splitlines())}
    python = {c["name"]: c for c in map(json.loads, fixtures.splitlines()) if c["name"] != "rng"}
    fields: dict[str, dict] = {}
    nights = mismatched = 0
    values = []
    for name, case in python.items():
        nights += len(case["steps"])
        for a, b in zip(case["steps"], swift[name]["steps"]):
            mismatched += a["choice"]["offset"] != b["choice"]["offset"] or a["rng_state"] != b["rng_state"]
        for field, x, y in pairs(case, swift[name]):
            f = fields.setdefault(field, {"count": 0, "max_abs_diff": 0.0})
            f["count"] += 1
            f["max_abs_diff"] = max(f["max_abs_diff"], abs(x - y))
            values.append((field, x, y))
    report = {
        "cases": len(python),
        "nights": nights,
        "values": len(values),
        "choice_or_generator_mismatches": mismatched,
        "fields": fields,
        "points": [{"field": f, "python": x, "swift": y} for f, x, y in values if f in ("mean", "sd", "prob", "insight")],
    }
    (ROOT / "reports" / "parity.json").write_text(json.dumps(report) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "points"}, indent=2))


if __name__ == "__main__":
    main()
