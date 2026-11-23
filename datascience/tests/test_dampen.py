import numpy as np
import pytest

from dusk_model.artifact import Params
from export.v0 import artifact as v0
from sim.dampen import Policy, allowed_on, run
from sim.dampen_sweep import BY_NAME, make_world

BASE = Params.from_artifact(v0())


@pytest.mark.parametrize("name", ["v0", "k2", "step10", "weekly-settle-plan15", "settle-conf90"])
def test_dampened_starts_stay_allowed_and_logged(name):
    policy = BY_NAME[name]
    w = make_world("worse", 60, 11)
    r = run(w, BASE, policy, 11, draws=50)
    grid = np.array(policy.grid, dtype=float)
    allowed = allowed_on(grid, w.people.allowed)
    for k, a in enumerate(grid):
        assert not ((r.offset == a) & r.home & ~allowed[:, k][:, None]).any()
    assert np.isin(r.offset[r.home], grid).all()
    assert ((r.prob > 0) & (r.prob <= 1 + 1e-12))[r.home].all()


def test_step_caps_the_change_from_the_last_block_night():
    r = run(make_world("differ", 60, 12), BASE, BY_NAME["step5"], 12, draws=50)
    assert r.change[r.home].max() <= 5


def test_weekly_start_changes_only_on_mondays_until_settled():
    r = run(make_world("differ", 60, 13), BASE, Policy("weekly", dwell=7), 13, draws=50)
    nights = np.arange(r.offset.shape[1])
    moved = r.home & (r.change > 0)
    first_home = r.home & (np.cumsum(r.home, axis=1) == 1)
    after_away = np.zeros_like(r.home)
    after_away[:, 1:] = ~r.home[:, :-1]
    assert not (moved & (nights % 7 != 0)[None, :] & ~first_home & ~after_away).any()


def test_null_drift_keeps_the_people():
    w = make_world("null+drift", 30, 14)
    assert w.people.count == 30 and np.isfinite(w.noise).all()
