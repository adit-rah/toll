"""Night records from an Apple Health export (Health app › Profile › Export All Health Data).

Before Dusk runs nightly, a Health export alone covers the sleep side: each night becomes a record with
the block assumed at plan (offset 0, policy "fixed"), so the replay can measure how well the model
learns a person's intercept, weekend drift and late nights. Only sleep samples are read.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from pathlib import Path

SLEEP = "HKCategoryTypeIdentifierSleepAnalysis"
ASLEEP = {
    "HKCategoryValueSleepAnalysisAsleep",
    "HKCategoryValueSleepAnalysisAsleepUnspecified",
    "HKCategoryValueSleepAnalysisAsleepCore",
    "HKCategoryValueSleepAnalysisAsleepDeep",
    "HKCategoryValueSleepAnalysisAsleepREM",
}
AWAKE = "HKCategoryValueSleepAnalysisAwake"


def parse_time(value: str) -> datetime:
    """Health writes "2026-01-05 23:12:00 -0500"."""
    return datetime.strptime(value, "%Y-%m-%d %H:%M:%S %z")


def night_of(t: datetime) -> date:
    """Sleep starting from 6 pm to 2 pm the next day belongs to the evening's date."""
    return (t - timedelta(hours=14)).date() if t.time() < time(18) else t.date()


def sleep_samples(path: Path) -> dict[date, list[tuple[datetime, datetime, str, str]]]:
    nights: dict[date, list] = defaultdict(list)
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag == "Record" and el.get("type") == SLEEP:
            start, end = parse_time(el.get("startDate")), parse_time(el.get("endDate"))
            nights[night_of(start)].append((start, end, el.get("value"), el.get("sourceName", "")))
        el.clear()
    return nights


def _source(samples: list) -> str:
    """One source per night (the watch if it reported), so phone and watch don't double count."""
    asleep = [s for s in samples if s[2] in ASLEEP]
    names = {s[3] for s in asleep}
    watch = sorted(n for n in names if "watch" in n.lower())
    if watch:
        return watch[0]
    return max(sorted(names), key=lambda n: sum(1 for s in asleep if s[3] == n)) if names else ""


def records(
    path: Path, bedtime: time, weekend_bedtime: time, sleep_hours: float = 8.0, version: str = "health-export"
) -> list[dict]:
    """One record per night with sleep data, in date order."""
    out = []
    for night, samples in sorted(sleep_samples(path).items()):
        source = _source(samples)
        mine = [s for s in samples if s[3] == source]
        asleep = [s for s in mine if s[2] in ASLEEP]
        if not asleep:
            continue
        weekend = night.weekday() in (4, 5)
        tz = asleep[0][0].tzinfo
        planned = datetime.combine(night, weekend_bedtime if weekend else bedtime, tz)
        if planned.time() < time(12):
            planned += timedelta(days=1)
        wake = planned + timedelta(hours=sleep_hours)
        onset = min(s[0] for s in asleep)
        offsets = {s[0].utcoffset() for s in mine}
        out.append(
            {
                "night": night.isoformat(),
                "planned_bedtime": planned.isoformat(),
                "bed": planned.isoformat(),
                "gap_min": 0,
                "planned_wake": wake.isoformat(),
                "block_start": planned.isoformat(),
                "block_end": wake.isoformat(),
                "action_offset_min": 0,
                "action_prob": 1.0,
                "model_version": version,
                "policy": "fixed",
                "home_arrival": None,
                "away_all_night": False,
                "weekend": weekend,
                "tz_changed": len(offsets) > 1,
                "block_screens": None,
                "unlocks_used": None,
                "unlocks_returned": None,
                "sleep_onset": onset.isoformat(),
                "wake": max(s[1] for s in asleep).isoformat(),
                "asleep_min": int(sum((s[1] - s[0]).total_seconds() for s in asleep) // 60),
                "awake_min": int(sum((s[1] - s[0]).total_seconds() for s in mine if s[2] == AWAKE) // 60),
                "sleep_source": "watch" if "watch" in source.lower() else "phone" if "phone" in source.lower() else "other",
            }
        )
    return out


def write_export(path: Path, nights: list[dict], source: str = "Apple Watch") -> None:
    """The reverse, for tests: a Health export holding these nights' sleep as core-sleep samples."""
    root = ET.Element("HealthData", locale="en_US")
    for n in nights:
        if n.get("sleep_onset") is None:
            continue
        onset = datetime.fromisoformat(n["sleep_onset"])
        end = onset + timedelta(minutes=n.get("asleep_min") or 420)
        ET.SubElement(
            root,
            "Record",
            type=SLEEP,
            sourceName=source,
            value="HKCategoryValueSleepAnalysisAsleepCore",
            startDate=onset.strftime("%Y-%m-%d %H:%M:%S %z"),
            endDate=end.strftime("%Y-%m-%d %H:%M:%S %z"),
        )
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)
