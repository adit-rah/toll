"""#154: the simulator's background change, and the model's wandering intercept and noise scale."""

import numpy as np
import pytest

from dusk_model.artifact import Params, validate
from dusk_model.model import cholesky, effective, mean, prior_state, scale2, update, wander
from export import v1, v2
from sim import wander as sim_wander
from sim.run import world

V2 = Params.from_artifact(v2.artifact())
WANDERS = Params.from_artifact(v2.artifact(intercept_week_sd=10.0))


def test_the_old_wander_is_unchanged():
    w = sim_wander.make_world("null+wander", 20, 5, nights=60)
    plain = world("null", 20, 5, nights=60)
    rho = float(np.exp(-1.0 / 28.0))
    steps = np.random.default_rng([5, 8]).normal(0.0, 15.0 * np.sqrt(1 - rho * rho), plain.noise.shape)
    level = np.random.default_rng([5, 9]).normal(0.0, 15.0, 20)
    for t in range(60):
        level = level if t == 0 else rho * level + steps[:, t]
        plain.noise[:, t] += level
    np.testing.assert_array_equal(w.noise, plain.noise)


def test_a_profile_sets_the_level_by_calendar_week():
    level = sim_wander.weekly_level(sim_wander.PROFILES["slow"], 5, 30, seed=3)
    assert level.shape == (5, 30)
    for week in range(4):
        block = level[:, 7 * week : 7 * week + 7]
        assert np.all(block == block[:, :1])
    assert not np.allclose(level[:, 0], level[:, 7])


def test_the_wide_profile_has_heavy_tailed_nights():
    w = sim_wander.make_world("null+wide", 300, 4, nights=7 * 20)
    deviation = w.noise.reshape(300, 20, 7)
    deviation = deviation - np.median(deviation, axis=2, keepdims=True)
    beyond = float((np.abs(deviation) > 90).mean())
    assert 0.1 < beyond < 0.3


def test_wander_keeps_the_mean_and_adds_to_the_intercept_variance():
    rng = np.random.default_rng(1)
    a = rng.normal(size=(3, 4, 4))
    lam = a @ a.transpose(0, 2, 1) / 100 + np.eye(4)[None] * 0.01
    b = rng.normal(size=(3, 4))
    moved, b2 = wander(lam, b, np.array([0.0, 1.0, 3.0]), WANDERS)
    q = WANDERS.intercept_week_sd**2
    for i, weeks in enumerate((0.0, 1.0, 3.0)):
        sigma = np.linalg.inv(lam[i])
        np.testing.assert_allclose(np.linalg.inv(moved[i]), sigma + q * weeks * np.diag([1, 0, 0, 0]), rtol=1e-9)
        np.testing.assert_allclose(np.linalg.solve(moved[i], b2[i]), np.linalg.solve(lam[i], b[i]), rtol=1e-9)


def nights_of(params: Params, people: int, weeks: int, week_sd: float, seed: int) -> np.ndarray:
    """κ² after `weeks` weeks of nights drawn as the model expects them, plus a level per week."""
    rng = np.random.default_rng(seed)
    state = prior_state(params, people)
    level = rng.normal(0.0, week_sd, (people, weeks))
    for t in range(7 * weeks):
        phi = np.column_stack([np.ones(people), np.zeros(people), np.zeros(people), np.zeros(people)])
        y = params.theta[0] + level[:, t // 7] + rng.normal(0.0, params.noise_sd, people)
        update(state, phi, y, np.ones(people, dtype=bool), params, week=np.full(people, 100 + t // 7))
    return scale2(state, params)


def test_the_scale_stays_near_one_when_the_model_is_right_and_grows_when_weeks_move():
    calm = nights_of(V2, 400, 26, 0.0, seed=2)
    moving = nights_of(V2, 400, 26, 40.0, seed=2)
    assert 0.8 < float(np.median(calm)) < 1.25
    assert float(np.median(moving)) > 2.0


def test_ranges_are_drawn_from_the_scaled_covariance():
    state = prior_state(V2, 2)
    state.scale_sum[:] = [0.0, 70.0]
    state.scale_nights[:] = [0.0, 14.0]
    k2 = scale2(state, V2)
    lam, b = effective(state, V2)
    np.testing.assert_allclose(lam[1], state.precision[1] / k2[1])
    L = cholesky(lam)
    np.testing.assert_allclose(mean(L, b), mean(cholesky(state.precision), state.b))
    assert k2[0] == 1.0 and k2[1] > 2.0


def test_schema_three_needs_its_fields_and_schema_two_reads_without():
    old = Params.from_artifact(v1.artifact())
    assert old.intercept_week_sd == 0 and old.noise_scale_prior_nights == 0
    a = v2.artifact()
    del a["noise_scale_prior_nights"]
    with pytest.raises(ValueError):
        validate(a)
    a = v2.artifact() | {"intercept_week_sd": -1.0}
    with pytest.raises(ValueError):
        validate(a)
