"""Writes the artifact and the fixtures, then copies both into the Swift package.

    uv run python -m export

Deterministic: running it twice gives the same bytes, and CI checks the committed files match.
"""

from __future__ import annotations

import json
from pathlib import Path

from dusk_model import artifact

from .fixtures import all_cases, check_nonempty, rng_case
from .rebuild import case as rebuild_case
from .versions import VERSIONS

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"


def main() -> None:
    for version in VERSIONS:
        path = ARTIFACTS / f"{version.VERSION}.json"
        path.write_text(artifact.dumps(version.artifact()))
    cases = all_cases()
    check_nonempty(cases)
    lines = [json.dumps(rng_case())] + [json.dumps(c) for c in cases]
    (ARTIFACTS / "fixtures.jsonl").write_text("\n".join(lines) + "\n")
    (ARTIFACTS / "rebuild.json").write_text(json.dumps(rebuild_case()) + "\n")
    names = ", ".join(f"{v.VERSION}.json" for v in VERSIONS)
    print(f"wrote {names}, {len(lines)} fixture cases and the rebuild fixture")


if __name__ == "__main__":
    main()
