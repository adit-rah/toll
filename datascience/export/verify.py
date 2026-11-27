"""Checks the committed artifact and fixtures are what the code exports, for CI.

The artifact must match byte for byte. The fixtures come from simulated nights whose last bits can
depend on the CPU's maths library, so numbers must agree to 1e-9 and everything else exactly.

    uv run python -m export.verify
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from dusk_model import artifact

from .fixtures import all_cases, rng_case
from .rebuild import case as rebuild_case
from .versions import VERSIONS

ROOT = Path(__file__).resolve().parents[1]


def same(a, b, path: str, problems: list[str]) -> None:
    if isinstance(a, float) or isinstance(b, float):
        if not isinstance(a, (int, float)) or not isinstance(b, (int, float)) or not math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-9):
            problems.append(f"{path}: {a} != {b}")
    elif isinstance(a, dict) and isinstance(b, dict):
        if a.keys() != b.keys():
            problems.append(f"{path}: keys differ")
        for k in a.keys() & b.keys():
            same(a[k], b[k], f"{path}.{k}", problems)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            problems.append(f"{path}: length {len(a)} != {len(b)}")
        for i, (x, y) in enumerate(zip(a, b)):
            same(x, y, f"{path}[{i}]", problems)
    elif a != b:
        problems.append(f"{path}: {a!r} != {b!r}")


def main() -> None:
    problems: list[str] = []
    for version in VERSIONS:
        committed = (ROOT / "artifacts" / f"{version.VERSION}.json").read_text()
        if committed != artifact.dumps(version.artifact()):
            problems.append(f"artifacts/{version.VERSION}.json is not what {version.__name__} writes")
    lines = (ROOT / "artifacts" / "fixtures.jsonl").read_text().splitlines()
    fresh = [rng_case()] + all_cases()
    same([json.loads(line) for line in lines], json.loads(json.dumps(fresh)), "fixtures", problems)
    committed_rebuild = json.loads((ROOT / "artifacts" / "rebuild.json").read_text())
    same(committed_rebuild, json.loads(json.dumps(rebuild_case())), "rebuild", problems)
    for p in problems[:20]:
        print(p)
    if problems:
        sys.exit(f"{len(problems)} differences: run `uv run python -m export` and commit")
    print("artifact and fixtures match the code")


if __name__ == "__main__":
    main()
