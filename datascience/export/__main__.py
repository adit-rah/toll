"""Writes the artifact and the fixtures, then copies both into the Swift package.

    uv run python -m export

Deterministic: running it twice gives the same bytes, and CI checks the committed files match.
"""

from __future__ import annotations

import json
from pathlib import Path

from dusk_model import artifact

from . import v0
from .fixtures import all_cases, check_nonempty, rng_case

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"


def main() -> None:
    text = artifact.dumps(v0.artifact())
    path = ARTIFACTS / f"{v0.VERSION}.json"
    path.write_text(text)
    cases = all_cases()
    check_nonempty(cases)
    lines = [json.dumps(rng_case())] + [json.dumps(c) for c in cases]
    (ARTIFACTS / "fixtures.jsonl").write_text("\n".join(lines) + "\n")
    print(f"wrote {path.name} and {len(lines)} fixture cases")


if __name__ == "__main__":
    main()
