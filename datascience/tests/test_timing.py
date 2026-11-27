"""Personal timing's held, settling week (D66) and the zero test over a year (#117)."""

from datetime import date, timedelta

import numpy as np
import pytest

from dusk_model import artifact
from dusk_model.artifact import Params
from dusk_model.insights import shown, zero_test_level
from dusk_model.model import prior_state
from dusk_model.night import Context
from dusk_model.person import PersonModel, SeededRNG, held, rebuild
from dusk_model.rng import SplitMix64Batch
from dusk_model.timing import EPOCH, Holds, choose, day_number, hold_of, period, policy_name
from export import v0, v1
from sim.criteria import first_insight_night
from sim.records import records
from sim.run import run, world

V1 = Params.from_artifact(v1.artifact())
V0 = Params.from_artifact(v0.artifact())


def nights(first: str, count: int) -> list[str]:
    day = date.fromisoformat(first)
    return [(day + timedelta(days=i)).isoformat() for i in range(count)]


def confident(effect: float, sd: float, nights_: int = 40, params: Params = V1):
    """One person whose start effect is `effect` with posterior sd about `sd`."""
    state = prior_state(params, 1)
    lam = np.diag([1 / 25.0, 1 / sd**2, 1 / 25.0, 1 / 25.0])
    state.precision[0] = lam
    state.b[0] = lam @ np.array([0.0, effect - params.theta[1], 0.0, 0.0])
    state.nights[0] = nights_
    return state


def test_holds_run_monday_to_sunday():
    assert EPOCH.weekday() == 0
    monday = date(2026, 11, 23)
    assert monday.weekday() == 0
    weeks = {period(d, V1) for d in nights("2026-11-23", 7)}
    assert weeks == {period(monday, V1)}
    assert period("2026-11-30", V1) == period(monday, V1) + 1
    assert period("2026-11-24", V0) != period(monday, V0)
    assert policy_name(V1) == "held" and policy_name(V0) == "thompson"


def test_a_start_is_held_all_week_and_drawn_once():
    person = PersonModel(V1)
    rng = SeededRNG(5)
    hold = person.choose_start("2026-11-23", Context(), rng)
    after_draw = rng.state
    for night in nights("2026-11-24", 6):
        assert person.choose_start(night, Context(), rng, held=hold) == hold
    assert rng.state == after_draw
    nxt = person.choose_start("2026-11-30", Context(), rng, held=hold)
    assert nxt["start"] == "2026-11-30" and rng.state != after_draw


def test_a_held_start_that_stops_being_allowed_is_redrawn_that_night():
    person = PersonModel(V1)
    rng = SeededRNG(8)
    hold = person.choose_start("2026-11-23", Context(), rng)
    others = [a for a in V1.actions if a != hold["offset"]]
    again = person.choose_start("2026-11-25", Context(), rng, allowed=others, held=hold)
    assert again["start"] == "2026-11-25" and again["offset"] in others


def test_settles_on_the_side_the_insight_supports_within_limits():
    state = confident(20.0, 4.0)
    assert shown(state, V1)[0][0]
    holds = Holds.none(1)
    everything = np.ones((1, 3), dtype=bool)
    never_earlier = np.array([[False, True, True]])
    rng = SplitMix64Batch(np.array([3], dtype=np.uint64))
    count = 2000
    got = [choose(state, holds, 9000 + 7 * i, np.zeros(1, bool), np.zeros(1, bool), everything, rng, V1) for i in range(count)]
    assert all(h.settled[0] for h in got)
    settled_start = np.mean([h.offset[0] == -30 for h in got])
    # About one week in 14 explores, and Thompson then picks −30 about 4 times in 5.
    assert 0.975 < settled_start < 0.995
    limited = choose(state, holds, 9000, np.zeros(1, bool), np.zeros(1, bool), never_earlier, rng, V1)
    assert limited.offset[0] in (0.0, 30.0)


def test_settles_at_the_plan_when_the_range_is_inside_15_minutes():
    state = confident(1.0, 3.0)
    ok, _, low, high = shown(state, V1)
    assert not ok[0] and -15 < low[0] and high[0] < 15
    rng = SplitMix64Batch(np.array([4], dtype=np.uint64))
    h = choose(state, Holds.none(1), 9000, np.zeros(1, bool), np.zeros(1, bool), np.ones((1, 3), bool), rng, V1)
    assert h.settled[0]
    # Too few nights: not settled, it draws.
    young = confident(1.0, 3.0, nights_=V1.min_nights - 1)
    h = choose(young, Holds.none(1), 9000, np.zeros(1, bool), np.zeros(1, bool), np.ones((1, 3), bool), rng, V1)
    assert not h.settled[0]


def test_settling_is_checked_afresh_each_week():
    rng = SplitMix64Batch(np.array([6], dtype=np.uint64))
    args = (np.zeros(1, bool), np.zeros(1, bool), np.ones((1, 3), bool), rng, V1)
    h = choose(confident(20.0, 4.0), Holds.none(1), 9000, *args)
    assert h.settled[0]
    h = choose(confident(5.0, 12.0), h, 9007, *args)
    assert not h.settled[0]


def test_the_logged_chance_is_the_chance_the_start_had():
    """Many independent streams from one state: each start comes up as often as its logged chance."""
    for state in (confident(20.0, 4.0), confident(6.0, 9.0, nights_=10)):
        people = 20000
        many = type(state)(
            np.repeat(state.precision, people, axis=0), np.repeat(state.b, people, axis=0), np.repeat(state.nights, people)
        )
        rng = SplitMix64Batch(np.arange(people, dtype=np.uint64) * np.uint64(7919))
        small = Params.from_artifact(v1.artifact(prob_draws=200))
        h = choose(many, Holds.none(people), 9000, np.zeros(people, bool), np.zeros(people, bool), np.ones((people, 3), bool), rng, small)
        for a in small.actions:
            picked = h.offset == a
            if picked.any():
                assert abs(picked.mean() - h.prob[picked].mean()) < 0.015


def test_the_hold_comes_back_from_the_night_log():
    w = world("differ", 3, 41)
    r = run(w, V1, "thompson", 41)
    log = records(w, r, 1, V1.version, "held", 41)
    assert all(rec["policy"] == "held" and rec["hold_start"] <= rec["night"] for rec in log)
    assert all(date.fromisoformat(rec["hold_start"]).weekday() == 0 for rec in log)
    hold = held(log)
    assert hold == hold_of(log[-1]) and hold["start"] == log[-1]["hold_start"]
    person = rebuild(V1, log)
    rng = SeededRNG(1)
    assert person.choose_start(log[-1]["night"], Context(), rng, held=hold) == hold
    assert held([rec | {"policy": "fixed"} for rec in log]) is None


def test_schema_2_needs_its_fields_and_schema_1_reads_as_v0():
    a = v1.artifact()
    del a["policy"]["hold_nights"]
    with pytest.raises(ValueError):
        artifact.validate(a)
    assert V0.hold_nights == 1 and not V0.settles and V0.zero_test_spend_after == 0
    assert zero_test_level(10_000, V0) == V0.zero_test_interval


def test_the_zero_test_tightens_only_after_its_nights():
    after = V1.zero_test_spend_after
    assert zero_test_level(after, V1) == V1.zero_test_interval
    levels = [zero_test_level(n, V1) for n in (after + 1, 2 * after, 4 * after, 10 * after)]
    assert all(a < b < 1 for a, b in zip(levels, levels[1:]))


def test_a_shown_insight_keeps_the_untightened_test():
    """Past the spending nights a new insight needs the stricter test; one already showing stays
    while the 98% test holds, and goes quietly when that fails too."""
    nights_ = 4 * V1.zero_test_spend_after
    state = confident(10.0, 3.7, nights_=nights_)  # clears 98% (z 2.33), not the tightened test
    assert not shown(state, V1)[0][0]
    state.shown[:] = True
    assert shown(state, V1)[0][0]
    weak = confident(7.0, 3.7, nights_=nights_)  # fails 98% too
    weak.shown[:] = True
    assert not shown(weak, V1)[0][0]


def ever_shown_in_null(params: Params, people: int, nights_: int, seed: int) -> np.ndarray:
    w = world("null", people, seed, nights=nights_)
    r = run(w, params, "thompson", seed)
    return first_insight_night(r.shown)


def test_false_insights_stay_under_5_percent_for_a_year():
    """#117: the insight is checked every night for as long as Dusk is used, so the 5% mark must hold
    past night 56. With v0's fixed zero test, D66's policy passes it within the year."""
    first = ever_shown_in_null(V1, 1500, 364, 20261127)
    assert (first <= 364).mean() <= 0.05
    fixed = Params.from_artifact(v1.artifact(zero_test_spend_after=0, zero_test_spend_power=0.0))
    assert (ever_shown_in_null(fixed, 1500, 364, 20261127) <= 364).mean() > 0.05
