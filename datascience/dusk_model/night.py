"""Night records (contract 1) and what the model takes from each one.

A record is a dict with the JSON field names. Times are local ISO 8601 with the offset.

Since the lock starts a gap before bed (decisions D76), `planned_bedtime` is bed, never the lock, and
records carry `bed` and `gap_min`: the lock was planned for bed minus `gap_min`. Records from before
have neither; their gap was 0 and their `planned_bedtime` was bed.

Since the helpers before bed (decisions D80), records carry `helper`: which one was last opened in
the gap that night ("list", "breathe" or "words"), or null. It is private to the pilot: never shown
to the person and never a model feature. Records from before have no `helper`; none was used.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

import numpy as np

from .artifact import Params

RECORD_FIELDS = [
    "night",
    "planned_bedtime",
    "planned_wake",
    "block_start",
    "block_end",
    "action_offset_min",
    "action_prob",
    "model_version",
    "policy",
    "home_arrival",
    "away_all_night",
    "weekend",
    "tz_changed",
    "block_screens",
    "unlocks_used",
    "unlocks_returned",
    "sleep_onset",
    "wake",
    "asleep_min",
    "awake_min",
    "sleep_source",
    "bed",
    "gap_min",
    "helper",
]

HELPERS = ("list", "breathe", "words")


@dataclass(frozen=True)
class Context:
    """What is known about a night before it starts."""

    weekend: bool = False
    late: bool = False


@dataclass(frozen=True)
class NightFeatures:
    usable: bool
    skip: str | None
    y: float
    offset: int
    context: Context


def phi(offset: float, context: Context) -> np.ndarray:
    return np.array([1.0, offset / 30.0, float(context.weekend), float(context.late)])


def _time(value: str | None) -> datetime | None:
    return None if value is None else datetime.fromisoformat(value)


def _minutes(later: datetime, earlier: datetime) -> float:
    return (later - earlier).total_seconds() / 60.0


def bed_of(record: dict) -> datetime:
    """Bed: sleep onset is measured from it, never from the lock."""
    return _time(record.get("bed") or record["planned_bedtime"])


def gap_of(record: dict) -> int:
    """Minutes the lock was planned to start before bed."""
    return int(record.get("gap_min") or 0)


def helper_of(record: dict) -> str | None:
    """The helper last opened before bed that night, or None; unknown values read as None."""
    helper = record.get("helper")
    return helper if helper in HELPERS else None


def context_of(record: dict, params: Params) -> Context:
    bedtime = bed_of(record)
    arrival = _time(record.get("home_arrival"))
    late = arrival is not None and _minutes(bedtime, arrival) < params.late_home_within_min
    return Context(weekend=bool(record["weekend"]), late=late)


def features(record: dict, params: Params) -> NightFeatures:
    """Skips in a fixed order so Swift reports the same reason."""
    context = context_of(record, params)
    offset = int(record["action_offset_min"])
    onset = _time(record.get("sleep_onset"))

    def skip(reason: str) -> NightFeatures:
        return NightFeatures(False, reason, 0.0, offset, context)

    if onset is None:
        return skip("no_sleep_data")
    if record["away_all_night"]:
        return skip("away")
    if record["tz_changed"]:
        return skip("tz_changed")
    if record.get("block_start") is None:
        return skip("no_block")
    if offset not in params.actions:
        return skip("unknown_action")
    y = _minutes(onset, bed_of(record))
    if abs(y) > params.max_onset_from_plan_min:
        return skip("onset_far")
    return NightFeatures(True, None, y, offset, context)
