import numpy as np

from economy import fixtures
from economy.buffers import D97, Fitting, fitted_judge
from economy.pauses import Behaviour, Economy, simulate
from economy.suggest import HARD, HOLD, OFF, SMOOTH, Week, late_onset, suggest, target, verdict
from sim.gap_rule import GapState


def test_the_committed_fixtures_are_what_the_reference_writes():
    body = fixtures.text()
    assert fixtures.OUT.read_text() == body
    assert fixtures.SWIFT.read_text() == body


def test_too_few_weeks_keep_the_baseline():
    weeks = [Week(30, SMOOTH, 0), Week(45, SMOOTH, 0), Week(60, HOLD, 0)]
    assert target("before", weeks, True) is None
    assert suggest(weeks, [], True) == {"before": 60, "after": 30, "fitted": []}


def test_a_level_hard_twice_brings_the_target_a_step_below():
    weeks = [Week(30, SMOOTH, 0), Week(45, SMOOTH, 0), Week(60, HARD, 2), Week(45, SMOOTH, 0), Week(60, HARD, 3)]
    assert target("before", weeks, False) == 45


def test_raising_needs_healths_sign_and_never_passes_90():
    calm = [Week(30, SMOOTH, 0), Week(45, SMOOTH, 0), Week(60, SMOOTH, 0), Week(60, SMOOTH, 0), Week(60, SMOOTH, 0)]
    assert target("before", calm, False) == 60
    assert target("before", calm, True) == 75
    at_90 = calm + [Week(90, SMOOTH, 0)] * 3
    assert target("before", at_90, True) == 90
    assert target("after", [Week(30, SMOOTH, 0)] * 5, True) == 30


def test_the_after_side_stays_between_15_and_30():
    assert target("after", [Week(30, HARD, 2), Week(15, SMOOTH, 0)] * 2, False) == 15
    assert target("after", [Week(15, OFF, 0)] * 4, False) == 15


def test_verdict_and_late_onset_match_the_weekly_rule():
    assert verdict(4, 1, False) == SMOOTH
    assert verdict(3, 0, False) == HOLD
    assert verdict(6, 2, False) == HARD
    assert verdict(6, 0, True) == OFF
    assert late_onset([20] * 14) and not late_onset([20] * 13) and not late_onset([19] * 20)


def test_the_fitted_judge_lowers_a_buffer_that_keeps_going_hard():
    s = GapState.start(2, D97)
    judge = fitted_judge(Fitting())
    nights = np.array([6, 6])
    weeks = [(0, 0), (0, 0), (2, 0), (0, 0), (0, 0), (2, 0), (0, 0), (0, 0), (0, 0)]
    for monday, (a, b) in enumerate(weeks, start=1):
        judge(s, D97, monday, nights, np.array([a, b]), np.array([False, False]))
    assert s.gap[1] == 60
    assert s.gap[0] == 45 and s.cap[0] == 45


def test_pauses_spend_and_refill_each_monday():
    r = simulate(Economy(), Behaviour(urges_median=5.0, urges_sd=0.0, patience_median_s=1e9, off_per_refusal=0.0,
                                      off_background=0.0, home=1.0), 50, 14, 1)
    assert (r.used == 3).all()
    assert r.ran_out.all() and (r.refused > 0).all()
    none = simulate(Economy(per_week=0), Behaviour(off_background=0.0), 50, 14, 1)
    assert none.used.sum() == 0 and none.paused_min.sum() == 0
