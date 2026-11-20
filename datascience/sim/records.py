"""Night records for simulated people, in the shape the app writes (contract 1).

They let the replay harness and the safety check read the simulator's nights exactly as they would
read a phone's export.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import numpy as np

from .run import Run, World

START = datetime(2026, 1, 5, tzinfo=timezone(timedelta(hours=-5)))  # a Monday


def _iso(t: datetime | None) -> str | None:
    return None if t is None else t.isoformat()


def records(w: World, r: Run, person: int, model_version: str, policy: str, seed: int = 0) -> list[dict]:
    rng = np.random.default_rng([seed, person])
    bedtime_min = 22 * 60 + 30 * int(rng.integers(0, 4))  # 22:00 to 23:30
    out = []
    for t in range(r.offset.shape[1]):
        day = START + timedelta(days=t)
        bedtime = day + timedelta(minutes=bedtime_min + (30 if w.weekend[person, t] else 0))
        wake = bedtime + timedelta(hours=8)
        home = bool(r.home[person, t])
        offset = int(r.offset[person, t])
        if not home or w.people.while_using[person]:
            arrival = None
        elif w.late[person, t]:
            arrival = bedtime - timedelta(minutes=float(rng.uniform(0, 59)))
        else:
            arrival = bedtime - timedelta(minutes=float(rng.uniform(120, 360)))
        # Away nights still have Health data (the watch goes too); the model skips them as away.
        missing = bool(w.missing[person, t])
        onset = None if missing else bedtime + timedelta(minutes=float(r.measured[person, t]))
        out.append(
            {
                "night": day.date().isoformat(),
                "planned_bedtime": _iso(bedtime),
                "planned_wake": _iso(wake),
                "block_start": _iso(bedtime + timedelta(minutes=offset)) if home else None,
                "block_end": _iso(wake) if home else None,
                "action_offset_min": offset,
                "action_prob": float(r.prob[person, t]) if home else 1.0,
                "model_version": model_version,
                "policy": policy,
                "home_arrival": _iso(arrival),
                "away_all_night": not home,
                "weekend": bool(w.weekend[person, t]),
                "tz_changed": bool(w.tz_changed[person, t]),
                "block_screens": int(rng.poisson(2)) if home else 0,
                "unlocks_used": int(rng.random() < 0.1) if home else 0,
                "unlocks_returned": 0,
                "sleep_onset": _iso(onset),
                "wake": None if missing else _iso(wake),
                "asleep_min": None if missing else int(round(480 - r.measured[person, t])),
                "awake_min": None if missing else int(rng.integers(5, 40)),
                "sleep_source": None if missing else "watch",
            }
        )
    return out
