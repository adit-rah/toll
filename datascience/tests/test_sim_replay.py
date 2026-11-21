from datetime import datetime

import numpy as np

from dusk_model.artifact import Params
from dusk_model.night import features
from export.v0 import artifact as v0
from replay.evaluate import replay
from replay.health import records as health_records
from replay.health import write_export
from sim.records import records
from sim.run import run, world

PARAMS = Params.from_artifact(v0())


def test_records_carry_what_the_simulator_did():
    w = world("differ", 20, 3)
    r = run(w, PARAMS, "thompson", 3)
    for p in range(20):
        for t, rec in enumerate(records(w, r, p, PARAMS.version, "thompson")):
            f = features(rec, PARAMS)
            assert f.usable == r.usable[p, t]
            if f.usable:
                assert abs(f.y - r.measured[p, t]) < 1e-6
                assert f.offset == r.offset[p, t]
                assert f.context.late == w.late_seen[p, t]
            if rec["block_start"] is not None:
                assert rec["block_end"] == rec["planned_wake"]


def test_policy_never_leaves_allowed_starts():
    w = world("worse", 300, 4)
    r = run(w, PARAMS, "thompson", 4)
    for k, a in enumerate([-30, 0, 30]):
        assert not ((r.offset == a) & r.home & ~w.people.allowed[:, k][:, None]).any()


def test_health_export_round_trip_and_replay(tmp_path):
    w = world("null", 1, 5)
    r = run(w, PARAMS, "fixed")
    nights = records(w, r, 0, PARAMS.version, "fixed")
    export = tmp_path / "export.xml"
    write_export(export, nights)
    bedtime = datetime.fromisoformat(nights[0]["planned_bedtime"]).time()
    weekend = datetime.fromisoformat(next(n for n in nights if n["weekend"])["planned_bedtime"]).time()
    parsed = health_records(export, bedtime, weekend)
    with_sleep = [n for n in nights if n["sleep_onset"] is not None]
    assert len(parsed) == len(with_sleep)
    for a, b in zip(parsed, with_sleep):
        assert a["sleep_onset"][:16] == b["sleep_onset"][:16]
        assert a["planned_bedtime"] == b["planned_bedtime"]
    report = replay(parsed, PARAMS)
    assert report["usable_nights"] > 30
    assert np.isfinite(report["mae_model"])
