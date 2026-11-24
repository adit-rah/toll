import numpy as np
import pytest

from dusk_model.artifact import Params
from dusk_model.model import prior_state
from export.v0 import artifact as v0
from sim.dampen import allowed_on, run as dampen_run
from sim.dampen_sweep import BY_NAME, make_world
from sim.gap import D66, Variant, loosen_intercept, run
from sim.gap_rule import GapRule, GapState, Tolerance, dose, judge, pause_chance

BASE = Params.from_artifact(v0())
RULE = GapRule()


def week(s, monday, nights=6, pauses=0, off=False):
    n = len(s.gap)
    return judge(s, RULE, monday, np.full(n, nights), np.full(n, pauses), np.full(n, off))


def test_without_a_gap_it_is_d66():
    w = make_world("differ", 80, 21)
    a = dampen_run(w, BASE, BY_NAME["weekly-settle-plan15"], 21, draws=50)
    b = run(w, BASE, Variant("d66", rule=None, tolerance=None), 21, draws=50)
    for k in ("offset", "prob", "gain", "shown", "estimate", "settled", "settled_target"):
        assert np.array_equal(getattr(a, k), getattr(b, k)), k
    assert (b.gap == 0).all() and not b.dropped.any()


def test_smooth_weeks_grow_by_15_up_to_60():
    s = GapState.start(1, RULE)
    for monday in range(1, 7):
        week(s, monday)
    assert s.gap[0] == 60


def test_a_hard_week_eases_and_two_smooth_weeks_are_needed_after():
    s = GapState.start(1, RULE)
    week(s, 1)
    week(s, 2)
    assert s.gap[0] == 45
    week(s, 3, pauses=2)
    assert s.gap[0] == 30
    week(s, 4)
    assert s.gap[0] == 30
    week(s, 5)
    assert s.gap[0] == 45
    week(s, 6)
    assert s.gap[0] == 60


def test_a_hold_week_breaks_the_smooth_run():
    s = GapState.start(1, RULE)
    week(s, 1, pauses=2)
    week(s, 2)
    week(s, 3, nights=3)
    week(s, 4)
    assert s.gap[0] == 0
    week(s, 5)
    assert s.gap[0] == 15


def test_screen_time_off_eases_and_stops_growth_for_two_weeks():
    s = GapState.start(1, RULE)
    week(s, 1)
    week(s, 2, pauses=2, off=True)
    assert s.gap[0] == 15
    for monday in (3, 4):
        week(s, monday)
        assert s.gap[0] == 15
    week(s, 5)
    assert s.gap[0] == 30


def test_stopped_gap_can_ease_but_not_grow_and_fixed_never_moves():
    s = GapState.start(1, RULE)
    s.stopped[:] = True
    week(s, 1)
    assert s.gap[0] == 15
    week(s, 2, pauses=3)
    assert s.gap[0] == 0
    fixed = GapRule(grows=False, start=30)
    f = GapState.start(1, fixed)
    judge(f, fixed, 1, np.array([6]), np.array([3]), np.array([True]))
    assert f.gap[0] == 30


def test_pauses_are_rare_within_comfort_and_rise_past_it():
    tol = Tolerance()
    comfort = np.full(5, 40.0)
    chance = pause_chance(np.array([-15.0, 0.0, 30.0, 60.0, 400.0]), comfort, tol)
    assert chance[0] == chance[1] == 0.0
    assert chance[2] == pytest.approx(tol.base_rate)
    assert tol.base_rate < chance[3] < chance[4] <= tol.max_rate


def test_saturating_dose_counts_half_past_30():
    assert dose(np.array([15.0, 30.0, 60.0]), "saturating").tolist() == [15.0, 30.0, 45.0]
    assert dose(np.array([60.0]), "linear").tolist() == [60.0]


def test_loosening_keeps_the_mean_and_widens_the_intercept():
    params = D66.params(BASE, 50)
    state = prior_state(params, 2)
    state.precision = state.precision + np.eye(4)[None] * np.array([0.5, 2.0])[:, None, None]
    state.b = np.array([[1.0, 2.0, 0.0, -1.0], [0.5, 0.0, 1.0, 0.0]])
    mu = np.linalg.solve(state.precision, state.b[..., None])[..., 0]
    var = np.linalg.inv(state.precision)[:, 0, 0]
    loosen_intercept(state, np.array([True, False]), 10.0)
    assert np.allclose(np.linalg.solve(state.precision, state.b[..., None])[..., 0], mu)
    after = np.linalg.inv(state.precision)[:, 0, 0]
    assert after[0] == pytest.approx(var[0] + 100.0)
    assert after[1] == pytest.approx(var[1])


@pytest.mark.parametrize("variant", [Variant("B"), Variant("D", timing="after"), Variant("C", timing="first"),
                                     Variant("B-bed", feature="bed")])
def test_starts_stay_allowed_and_the_gap_stays_in_bounds(variant):
    w = make_world("worse", 80, 22)
    r = run(w, BASE, variant, 22, draws=50)
    grid = np.array(D66.grid, dtype=float)
    allowed = allowed_on(grid, w.people.allowed)
    for k, a in enumerate(grid):
        assert not ((r.offset == a) & r.home & ~allowed[:, k][:, None]).any()
    assert ((r.prob > 0) & (r.prob <= 1 + 1e-12))[r.home].all()
    assert r.gap.min() >= 0 and r.gap.max() <= 60
    assert (-r.start[r.home]).max() <= 90
    assert not (r.home & r.dropped).any()


def test_after_waits_for_the_gap_and_first_holds_it():
    w = make_world("differ", 80, 23)
    after = run(w, BASE, Variant("D", timing="after"), 23, draws=50)
    assert not ((after.offset != 0) & ~after.timing_on).any()
    started = after.timing_on.argmax(axis=1)[after.timing_on.any(axis=1)]
    assert (started % 7 == 0).all() and (started > 0).all()
    first = run(w, BASE, Variant("C", timing="first"), 23, draws=50)
    grew = np.diff(first.gap, axis=1) > 0
    assert not (grew & ~first.settled[:, 1:]).any()
