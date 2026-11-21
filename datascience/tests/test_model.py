import numpy as np
import pytest

from dusk_model import artifact
from dusk_model.artifact import Params
from dusk_model.insights import normal_quantile, shown
from dusk_model.model import cholesky, mean, predict, prior_state, update
from dusk_model.night import Context, features
from dusk_model.person import PersonModel, SeededRNG
from dusk_model.policy import choose
from dusk_model.rng import SplitMix64, SplitMix64Batch
from export.v0 import artifact as v0

PARAMS = Params.from_artifact(v0())
NO_FORGETTING = Params.from_artifact(v0() | {"forgetting": 1.0})


def test_splitmix64_known_values():
    # Published SplitMix64 outputs for seed 0.
    assert [int(x) for x in SplitMix64(0).u64(3)] == [
        0xE220A8397B1DCDAF,
        0x6E789E6AA1B965F4,
        0x06C45D188009454F,
    ]


def test_blocks_continue_one_stream():
    whole = SplitMix64(42).uniform(10)
    rng = SplitMix64(42)
    assert np.array_equal(np.concatenate([rng.uniform(3), rng.uniform(7)]), whole)
    batch = SplitMix64Batch(np.array([42, 7], dtype=np.uint64))
    assert np.array_equal(batch.uniform(10)[0], whole)


def test_normals_look_normal():
    z = SplitMix64(1).normal(200_000)
    assert abs(z.mean()) < 0.01 and abs(z.std() - 1) < 0.01


def random_state(rng: np.random.Generator, people: int = 50):
    state = prior_state(PARAMS, people)
    for _ in range(30):
        phi = np.column_stack(
            [np.ones(people), rng.choice([-1.0, 0.0, 1.0], people), rng.integers(0, 2, people), rng.integers(0, 2, people)]
        )
        update(state, phi, rng.normal(20, 40, people), rng.random(people) < 0.8, PARAMS)
    return state


def test_linear_algebra_matches_lapack():
    state = random_state(np.random.default_rng(0))
    L = cholesky(state.precision)
    assert np.allclose(L, np.linalg.cholesky(state.precision), rtol=1e-12, atol=1e-15)
    assert np.allclose(mean(L, state.b), np.linalg.solve(state.precision, state.b[..., None])[..., 0], rtol=1e-10)


def test_update_is_bayesian_linear_regression():
    rng = np.random.default_rng(1)
    phi = np.column_stack([np.ones(40), rng.choice([-1.0, 0.0, 1.0], 40), rng.integers(0, 2, 40), rng.integers(0, 2, 40)])
    y = rng.normal(10, 20, 40)
    p = NO_FORGETTING
    state = prior_state(p, 1)
    for t in range(40):
        update(state, phi[t : t + 1], y[t : t + 1], np.array([True]), p)
    s2 = p.noise_sd**2
    r = np.clip(y - phi @ p.theta, -90, 90)
    lam = np.diag(1 / p.prior_sd**2) + phi.T @ phi / s2
    assert np.allclose(state.precision[0], lam)
    assert np.allclose(state.b[0], phi.T @ r / s2)
    m, sd = predict(state, phi[:1], p)
    cov = np.linalg.inv(lam)
    assert np.isclose(sd[0] ** 2, phi[0] @ cov @ phi[0] + s2)
    assert np.isclose(m[0], phi[0] @ p.theta + phi[0] @ cov @ (phi.T @ r / s2))


def test_forgetting_discounts_old_nights_toward_the_prior():
    rng = np.random.default_rng(6)
    phi = np.column_stack([np.ones(30), rng.choice([-1.0, 0.0, 1.0], 30), rng.integers(0, 2, 30), rng.integers(0, 2, 30)])
    y = rng.normal(10, 20, 30)
    state = prior_state(PARAMS, 1)
    for t in range(30):
        update(state, phi[t : t + 1], y[t : t + 1], np.array([True]), PARAMS)
    g, s2 = PARAMS.forgetting, PARAMS.noise_sd**2
    weights = g ** (29 - np.arange(30))
    r = np.clip(y - phi @ PARAMS.theta, -90, 90)
    lam = np.diag(1 / PARAMS.prior_sd**2) + (phi * weights[:, None]).T @ phi / s2
    assert np.allclose(state.precision[0], lam)
    assert np.allclose(state.b[0], (phi * weights[:, None]).T @ r / s2)


def test_residual_is_clipped():
    state = prior_state(NO_FORGETTING, 1)
    phi = np.array([[1.0, 0.0, 0.0, 0.0]])
    update(state, phi, np.array([1000.0]), np.array([True]), NO_FORGETTING)
    assert state.b[0, 0] == pytest.approx(90 / 900)


def test_policy_floor_and_allowed_actions():
    state = random_state(np.random.default_rng(2), 400)
    allowed = np.ones((400, 3), dtype=bool)
    allowed[:100, 2] = False
    allowed[100:150] = [False, True, False]
    rng = SplitMix64Batch(np.arange(400, dtype=np.uint64))
    offset, prob = choose(state, np.zeros(400, bool), np.zeros(400, bool), allowed, rng, PARAMS)
    assert np.all(offset[:100] != 30)
    assert np.all(offset[100:150] == 0) and np.all(prob[100:150] == 1.0)
    assert np.all(prob[150:] >= PARAMS.min_prob - 1e-12)


def test_logged_probability_is_the_real_one():
    state = random_state(np.random.default_rng(3), 1)
    state = type(state)(
        np.repeat(state.precision, 4000, 0), np.repeat(state.b, 4000, 0), np.repeat(state.nights, 4000)
    )
    rng = SplitMix64Batch(np.arange(4000, dtype=np.uint64))
    offset, prob = choose(state, np.zeros(4000, bool), np.zeros(4000, bool), np.ones((4000, 3), bool), rng, PARAMS)
    for a in (-30, 0, 30):
        logged = prob[offset == a]
        if len(logged):
            assert abs((offset == a).mean() - logged.mean()) < 0.03


def test_quantile():
    assert normal_quantile(0.95) == pytest.approx(1.6448536269514722, abs=2e-9)
    assert normal_quantile(0.5) == 0.0
    assert normal_quantile(0.01) == pytest.approx(-2.3263478740408408, abs=5e-9)


def test_no_insight_before_min_nights():
    state = prior_state(PARAMS, 1)
    state.precision[0] *= 1e6
    state.b[0, 1] = 20 * state.precision[0, 1, 1]
    state.nights[0] = PARAMS.min_nights - 1
    assert not shown(state, PARAMS)[0][0]
    state.nights[0] = PARAMS.min_nights
    assert shown(state, PARAMS)[0][0]


def record(**changes):
    r = {
        "night": "2026-11-20",
        "planned_bedtime": "2026-11-20T23:00:00-05:00",
        "planned_wake": "2026-11-21T07:00:00-05:00",
        "block_start": "2026-11-20T22:30:00-05:00",
        "block_end": "2026-11-21T07:00:00-05:00",
        "action_offset_min": -30,
        "action_prob": 0.5,
        "model_version": "sleep-model.v0",
        "policy": "thompson",
        "home_arrival": "2026-11-20T18:00:00-05:00",
        "away_all_night": False,
        "weekend": False,
        "tz_changed": False,
        "sleep_onset": "2026-11-20T23:20:00-05:00",
    }
    r.update(changes)
    return r


def test_night_features_and_skips():
    f = features(record(), PARAMS)
    assert f.usable and f.y == 20.0 and f.offset == -30 and f.context == Context(False, False)
    assert features(record(home_arrival="2026-11-20T22:10:00-05:00"), PARAMS).context.late
    assert not features(record(home_arrival=None), PARAMS).context.late
    cases = {
        "no_sleep_data": record(sleep_onset=None),
        "away": record(away_all_night=True),
        "tz_changed": record(tz_changed=True),
        "no_block": record(block_start=None),
        "unknown_action": record(action_offset_min=15),
        "onset_far": record(sleep_onset="2026-11-21T03:30:00-05:00"),
    }
    for reason, r in cases.items():
        assert features(r, PARAMS).skip == reason


def test_person_model_round_trip():
    person = PersonModel(PARAMS)
    assert person.update(record()) == (True, None)
    again = PersonModel(PARAMS, person.state)
    assert again.predict(Context(), 0) == person.predict(Context(), 0)
    offset, prob = again.choose_offset(Context(), SeededRNG(9))
    assert offset in PARAMS.actions and 0.1 <= prob <= 0.8


def test_artifact_checksum():
    text = artifact.dumps(v0())
    assert artifact.checksum_ok(text)
    assert not artifact.checksum_ok(text.replace('"noise_sd": 30.0', '"noise_sd": 31.0'))
    bad = v0() | {"actions": [-30, 30]}
    with pytest.raises(ValueError):
        artifact.validate(bad)
