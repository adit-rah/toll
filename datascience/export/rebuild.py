"""The rebuild fixture: a night log as the app keeps it, and the person's state rebuilt from it.

When a new artifact ships, the app rebuilds each person's state by replaying their night log
(decisions D52; #140). The log holds every line ever written: each past shape of the record, two
copies of a night written by the monitor and the app, and corrections appended later with a higher
`rev` (Health's sleep arriving after the night). Readers take the highest `rev` per night, the first
written of equals. The Swift package must rebuild the same state from the same lines.
"""

from __future__ import annotations

import copy

from dusk_model.artifact import Params
from dusk_model.person import rebuild

from . import v0
from .fixtures import simulated_nights

SLEEP = ("sleep_onset", "wake", "asleep_min", "awake_min", "sleep_source")


def as_written(record: dict, shape: int) -> dict:
    """The line the app wrote that night, before Health: no sleep fields, in the shape of its day.

    0: the first record (D62). 1: with bed and the gap (D83). 2: with the helper (D85).
    3: with its own format and revision (#140). 4: format 3, with the buffer after waking (#144).
    """
    line = copy.deepcopy(record)
    for key in SLEEP:
        line[key] = None
    line["dusk"] = {"ran": line["block_start"] is not None, "stops": line["block_screens"], "door_asks": 0}
    if shape >= 1:
        line["bed"] = line["planned_bedtime"]
        line["gap_min"] = 0
        line["dusk"] |= {"locked_min": 480, "taps": []}
    if shape >= 2:
        line["helper"] = None
    if shape >= 3:
        line["record"] = 2
        line["rev"] = 1
        line["dusk"]["by"] = "app"
    if shape >= 4:
        line["record"] = 3
        line["gap_min"] = 30
        line["after_min"] = 15
    return line


def correction(record: dict, written: dict, rev: int | None = None) -> dict:
    """Health's sleep for a night already written: the same line with the sleep fields, one `rev` up."""
    line = copy.deepcopy(written)
    for key in SLEEP:
        line[key] = record[key]
    # A correction keeps its night's format: format 3 since #144, else 2 (#140).
    line["record"] = 3 if written.get("record") == 3 else 2
    line["rev"] = rev if rev is not None else int(written.get("rev") or 1) + 1
    return line


def lines() -> list[dict]:
    nights = simulated_nights("differ", 21)[:28]
    written = [as_written(r, shape=i * 5 // len(nights)) for i, r in enumerate(nights)]
    out = list(written)
    # The monitor and the app both wrote night 25: equal revisions, the first stands.
    monitor = copy.deepcopy(written[25])
    monitor["dusk"]["by"] = "monitor"
    out.insert(out.index(written[25]), monitor)
    # Health arrives later for most nights, out of order; night 3 is corrected twice.
    for i in list(range(0, 24, 2)) + list(range(1, 24, 2)):
        out.append(correction(nights[i], written[i]))
    out.append(correction(nights[3] | {"sleep_onset": nights[3]["planned_bedtime"]}, written[3], rev=3))
    # Two corrections of night 26 at the same revision: the first stands.
    out.append(correction(nights[26], written[26]))
    late = correction(nights[26], written[26])
    late["sleep_onset"] = late["planned_wake"]
    out.append(late)
    return out


def case() -> dict:
    a = v0.artifact()
    log = lines()
    person = rebuild(Params.from_artifact(a), log)
    return {"artifact": a, "lines": log, "state": person.state}
