import numpy as np

from trends import fixtures, noise
from trends.rule import STEADY, TOWARD, Rule, level_measure, looks, spread_measure, t_quantile, trimmed, winsorized
from trends.study import judge

WOBBLE = [-10, 10, -10, 10, -10, 10, 0]


def weeks(levels, wobble=WOBBLE):
    return [(7 * w + i, float(level + wobble[i])) for w, level in enumerate(levels) for i in range(7)]


def test_the_committed_fixtures_are_what_the_reference_writes():
    body = fixtures.text()
    assert fixtures.OUT.read_text() == body
    assert fixtures.SWIFT.read_text() == body


def test_trimmed_and_winsorized_set_a_fifth_aside():
    assert trimmed([1, 2, 3, 4, 100], 0.2) == 3
    assert trimmed([1, 2, 3], 0.2) == 2
    assert winsorized([100, 1, 2, 3, 4], 0.2) == [4, 2, 2, 3, 4]


def test_t_quantile_is_close_to_students():
    for p, df, exact in [(0.995, 8, 3.3554), (0.995, 10, 3.1693), (0.9995, 10, 4.5869), (0.975, 30, 2.0423)]:
        assert abs(t_quantile(p, df) - exact) / exact < 1e-3


def test_one_wild_night_neither_makes_nor_hides_a_change():
    flat = weeks([720, 720])
    flat[10] = (10, flat[10][1] - 300)
    assert level_measure(flat, 14, 15.0, True)["change"]["way"] == STEADY
    moved = weeks([720, 680])
    moved[10] = (10, moved[10][1] + 300)
    assert level_measure(moved, 14, 15.0, True)["change"]["way"] == TOWARD


def test_the_line_is_judged_once_a_week():
    nights = weeks([720, 690, 690])
    sunday = level_measure(nights, 13, 15.0, True)
    monday = level_measure(nights, 14, 15.0, True)
    assert sunday["change"] is None
    assert monday["change"]["way"] == TOWARD and monday["change"]["look"] == 1
    for day in range(14, 21):
        assert level_measure(nights, day, 15.0, True)["change"] == monday["change"]
    assert level_measure(nights, 21, 15.0, True)["change"]["look"] == 2


def test_the_test_grows_with_the_looks_and_a_said_change_is_kept():
    rule = Rule()
    assert rule.z(1, 30) < rule.z(4, 30) < rule.z(12, 30)
    nights = weeks([720, 690, 690, 690, 690, 690, 698], [-8, 8, -8, 8, -8, 8, 0])
    found, _ = looks(nights, 49, 15.0, True, rule)
    assert [x.way for x in found] == [TOWARD] * 6
    # The last week's 22 min clears its own look's test only because it was said the week before.
    last = found[-1]
    assert rule.z(1, last.df) * last.se <= abs(last.d) < rule.z(last.look, last.df) * last.se


def test_how_steady_compares_two_weeks():
    nights = [(d, 700.0 + (40 if d % 2 else -40) * (1 if d < 14 else 0.2)) for d in range(42)]
    m = spread_measure(nights, 28)
    assert m["change"]["way"] == TOWARD and abs(m["value"] - 8) < 1e-9 and abs(m["first"] - 40) < 1e-9


def test_a_profile_still_has_no_wander_and_a_shuffle_no_level():
    gen = np.random.default_rng(1)
    p = noise.GRID["t15-150-l90-r0.2"]
    _, level = noise.nights(p.still(), 3, 4, gen)
    assert not level.any()
    values, level = noise.nights(p, 3, 4, gen, shuffle=True)
    assert not level.any() and values.shape == (3, 28)


def test_measure_reads_a_profile_back():
    got = noise.expected(noise.Profile(core=25.0), 30, people=60)
    assert abs(got["within_sd"] - 25) < 2 and got["weekly_sd"] < 15


def test_few_people_with_no_change_are_told_of_one():
    out = judge(("sim", vars(noise.GRID["sim"]), "still", vars(Rule()), 400, 3, False))
    assert out["level"]["ever_claim_by_26"] <= 0.08
    assert out["steady"]["ever_claim_by_26"] <= 0.08
