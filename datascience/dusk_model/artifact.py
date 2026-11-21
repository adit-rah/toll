"""The model artifact: the JSON file of numbers the app ships (contract 2 in the model spec).

The checksum covers the file's own bytes with the sha256 value written as "", so a build machine can
check it with sed and shasum and no JSON tools.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path

import numpy as np

SCHEMA = 1
FEATURES = ["intercept", "offset_per_30", "weekend", "late"]
_SHA_FIELD = re.compile(r'"sha256": "[0-9a-f]*"')


@dataclass(frozen=True)
class Params:
    """The artifact's numbers, read once."""

    version: str
    theta: np.ndarray
    prior_mean: np.ndarray
    prior_sd: np.ndarray
    noise_sd: float
    forgetting: float
    actions: tuple[int, ...]
    min_prob: float
    prob_draws: int
    late_home_within_min: float
    max_onset_from_plan_min: float
    residual_clip_min: float
    interval: float
    zero_test_interval: float
    max_width_min: float
    min_nights: int

    @classmethod
    def from_artifact(cls, a: dict) -> "Params":
        validate(a)
        return cls(
            version=a["version"],
            theta=np.array(a["base"]["theta"], dtype=float),
            prior_mean=np.array(a["prior"]["mean"], dtype=float),
            prior_sd=np.array(a["prior"]["cov_diag_sd"], dtype=float),
            noise_sd=float(a["noise_sd"]),
            forgetting=float(a["forgetting"]),
            actions=tuple(int(x) for x in a["actions"]),
            min_prob=float(a["policy"]["min_prob"]),
            prob_draws=int(a["policy"]["prob_draws"]),
            late_home_within_min=float(a["context"]["late_home_within_min"]),
            max_onset_from_plan_min=float(a["usable_night"]["max_onset_from_plan_min"]),
            residual_clip_min=float(a["usable_night"]["residual_clip_min"]),
            interval=float(a["insight"]["interval"]),
            zero_test_interval=float(a["insight"]["zero_test_interval"]),
            max_width_min=float(a["insight"]["max_width_min"]),
            min_nights=int(a["insight"]["min_nights"]),
        )


def validate(a: dict) -> None:
    """The same checks the Swift decoder makes, so an artifact Python accepts the app accepts."""
    if a.get("schema") != SCHEMA:
        raise ValueError(f"schema {a.get('schema')} is not {SCHEMA}")
    if a["features"] != FEATURES:
        raise ValueError("features must be " + ", ".join(FEATURES))
    for key in (a["base"]["theta"], a["prior"]["mean"], a["prior"]["cov_diag_sd"]):
        if len(key) != 4:
            raise ValueError("theta, prior mean and prior sd take 4 numbers")
    if min(a["prior"]["cov_diag_sd"]) <= 0 or a["noise_sd"] <= 0:
        raise ValueError("standard deviations must be positive")
    if not 0 < a["forgetting"] <= 1:
        raise ValueError("forgetting must be in (0, 1]")
    actions = a["actions"]
    if not actions or 0 not in actions or len(set(actions)) != len(actions):
        raise ValueError("actions must be distinct and include 0")
    if a["policy"]["min_prob"] * len(actions) > 1 or a["policy"]["min_prob"] < 0:
        raise ValueError("min_prob times the number of actions must be at most 1")
    if a["policy"]["prob_draws"] < 1:
        raise ValueError("prob_draws must be positive")
    if not 0 < a["insight"]["interval"] <= a["insight"]["zero_test_interval"] < 1:
        raise ValueError("need 0 < interval <= zero_test_interval < 1")


def dumps(a: dict) -> str:
    """The artifact as written to disk, checksum included."""
    body = {k: v for k, v in a.items() if k != "sha256"}
    body["sha256"] = ""
    text = json.dumps(body, indent=2) + "\n"
    digest = hashlib.sha256(text.encode()).hexdigest()
    return text.replace('"sha256": ""', f'"sha256": "{digest}"', 1)


def checksum_ok(text: str) -> bool:
    match = _SHA_FIELD.search(text)
    if not match:
        return False
    blank = _SHA_FIELD.sub('"sha256": ""', text, count=1)
    return match.group(0) == f'"sha256": "{hashlib.sha256(blank.encode()).hexdigest()}"'


def load(path: Path) -> dict:
    text = Path(path).read_text()
    if not checksum_ok(text):
        raise ValueError(f"{path}: checksum does not match")
    a = json.loads(text)
    validate(a)
    return a
