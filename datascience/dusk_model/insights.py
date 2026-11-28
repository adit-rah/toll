"""The one insight the model may state: what starting the block 30 minutes earlier does.

Its number is the base's offset coefficient plus the person's: minutes of later sleep per 30 minutes of
later start, which is the same as minutes of sooner sleep per 30 minutes earlier. Only this number may be
worded with "because", since only the start time was randomized.
"""

from __future__ import annotations

import math

import numpy as np

from .artifact import Params
from .model import State, cholesky, effective, forward, mean

KIND = "start_30_earlier"
WIDEN_INTERVAL = True


def normal_quantile(p: float) -> float:
    """Acklam's rational approximation (relative error under 1.2e-9). Swift carries the same code."""
    a = (-39.69683028665376, 220.9460984245205, -275.9285104469687, 138.3577518672690, -30.66479806614716, 2.506628277459239)
    b = (-54.47609879822406, 161.5858368580409, -155.6989798598866, 66.80131188771972, -13.28068155288572)
    c = (-0.007784894002430293, -0.3223964580411365, -2.400758277161838, -2.549732539343734, 4.374664141464968, 2.938163982698783)
    d = (0.007784695709041462, 0.3224671290700398, 2.445134137142996, 3.754408661907416)
    low = 0.02425
    if p < low:
        q = math.sqrt(-2.0 * math.log(p))
        return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / (
            (((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0
        )
    if p > 1.0 - low:
        q = math.sqrt(-2.0 * math.log(1.0 - p))
        return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / (
            (((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0
        )
    q = p - 0.5
    r = q * q
    return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (
        ((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0
    )


def start_effect(state: State, params: Params) -> tuple[np.ndarray, np.ndarray]:
    """Each person's estimate and its posterior sd (from κ²Σ, `model.effective`)."""
    lam, b = effective(state, params)
    L = cholesky(lam)
    mu = mean(L, b)
    unit = np.zeros_like(state.b)
    unit[:, 1] = 1.0
    v = forward(L, unit)
    sd = np.sqrt(v[:, 0] * v[:, 0] + v[:, 1] * v[:, 1] + v[:, 2] * v[:, 2] + v[:, 3] * v[:, 3])
    return params.theta[1] + mu[:, 1], sd


def zero_test_level(nights: int, params: Params) -> float:
    """The zero test's interval after `nights` usable nights.

    It is `zero_test_interval` up to `zero_test_spend_after` nights. After that its miss chance,
    1 − interval, shrinks as (spend_after / nights) ** spend_power: the insight is checked every night
    for as long as Dusk is used, and with one fixed test the share of people ever told about an effect
    that isn't there keeps growing past the 5% mark (#117, reports/longrun.md).
    """
    after = params.zero_test_spend_after
    if after <= 0 or nights <= after:
        return params.zero_test_interval
    miss = (1.0 - params.zero_test_interval) * math.pow(after / nights, params.zero_test_spend_power)
    return 1.0 - miss


def zero_test_z(nights: np.ndarray, params: Params) -> np.ndarray:
    """The zero test's z for each person, from their usable nights; scalar maths, as in Swift."""
    out = np.empty(len(nights))
    for n in np.unique(nights):
        out[nights == n] = normal_quantile(0.5 + zero_test_level(int(n), params) / 2.0)
    return out


def widen(z, nu: np.ndarray) -> np.ndarray:
    """A Student t quantile with nu degrees of freedom from the normal one, z: the Cornish–Fisher
    series to 1/ν⁴ (Abramowitz and Stegun 26.7.5). Swift carries the same code."""
    z2 = z * z
    g1 = (z2 + 1.0) * z / 4.0
    g2 = ((5.0 * z2 + 16.0) * z2 + 3.0) * z / 96.0
    g3 = (((3.0 * z2 + 19.0) * z2 + 17.0) * z2 - 15.0) * z / 384.0
    g4 = ((((79.0 * z2 + 776.0) * z2 + 1482.0) * z2 - 1920.0) * z2 - 945.0) * z / 92160.0
    return z + (g1 + (g2 + (g3 + g4 / nu) / nu) / nu) / nu


def scale_weeks(state: State, params: Params) -> np.ndarray:
    """How many weeks of evidence the noise's scale rests on, its prior included: the t's degrees
    of freedom, since each week's sum is one look at κ² (`model.scale2`)."""
    return (params.noise_scale_prior_nights + (state.scale_nights + state.week_nights)) / 7.0


def shown(state: State, params: Params) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Whether each person sees the insight: enough nights, a narrow shown range, and a stricter
    range clear of zero. Checking every night is many looks; the stricter range keeps the share of
    people told about an effect that isn't there under 5% (reports/tuning.md), and it tightens as the
    nights add up (`zero_test_level`). An insight already showing stays while the untightened test
    holds, so a person isn't told something and then has it taken away only because time passed;
    it is withdrawn quietly when even that fails (#117). When the noise's scale is learned, each
    range is a t's, with the weeks the scale rests on as degrees of freedom (#154)."""
    effect, sd = start_effect(state, params)
    z = normal_quantile(0.5 + params.interval / 2.0)
    strict = zero_test_z(state.nights, params)
    base = normal_quantile(0.5 + params.zero_test_interval / 2.0)
    if params.noise_scale_prior_nights > 0:
        nu = scale_weeks(state, params)
        strict, base = widen(strict, nu), widen(base, nu)
        z = widen(z, nu) if WIDEN_INTERVAL else z
    low, high = effect - z * sd, effect + z * sd
    clear_strict = (effect - strict * sd > 0) | (effect + strict * sd < 0)
    clear_base = (effect - base * sd > 0) | (effect + base * sd < 0)
    ok = (
        (state.nights >= params.min_nights)
        & (high - low < params.max_width_min)
        & (clear_strict | (state.shown & clear_base))
    )
    return ok, effect, low, high


def insights(state: State, params: Params, person: int = 0) -> list[dict]:
    ok, effect, low, high = shown(state, params)
    if not ok[person]:
        return []
    return [
        {
            "kind": KIND,
            "minutes": float(effect[person]),
            "low": float(low[person]),
            "high": float(high[person]),
            "nights": int(state.nights[person]),
        }
    ]
