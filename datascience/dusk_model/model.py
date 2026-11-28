"""The per-person adapter on a frozen base, for many people at once.

Every operation is written out in a fixed order (no LAPACK), so the Swift package, which does the same
steps one person at a time, gives the same numbers to rounding.

State per person: the precision matrix Λ (4×4), the vector b (4), the count of usable nights, and
whether the insight showed after the last night (`insights.shown` keeps a shown insight on a laxer test).
μ = Λ⁻¹ b and Σ = Λ⁻¹ come from the Cholesky factor L of Λ.

Since schema 3 (#154) the person's usual time can move between weeks, and a person can be noisier or
calmer than `noise_sd`:
- **The intercept wanders.** On a person's first usable night of a calendar week, the intercept's
  variance grows by `intercept_week_sd`² for each week since their last usable night (a Kalman step;
  μ stays). Without it, a week whose usual time moved reads as an effect of that week's held start.
- **The noise has a scale, by the week.** Each usable night's residual, before the night is learned,
  is divided by its predicted sd. If the model is right these are independent with variance 1, so a
  week's sum, squared, is about its count of nights. A person noisier than `noise_sd`, or whose usual
  time moves for days at a time, has bigger sums: the residuals of one week share a sign, and when it
  moves for weeks, so do one week's and the next's. κ² is the forgetting sum of the squared week
  sums and of each week's sum times the week before's (a long-run variance with a lag of one week,
  as Newey and West weigh it), over the forgetting count of their nights, with
  `noise_scale_prior_nights` nights of 1 added, and never below 1. Every range is drawn from κ²Σ
  (`effective`): a week that moves together counts as fewer nights.
The state carries the week of the last usable night (`week`, −1 before one), the folded sums
(`scale_sum`, `scale_cross`, `scale_nights`), the current week's (`week_sum`, `week_nights`) and the
week before's sum (`last_week_sum`).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .artifact import Params

N = 4
SCALE_FLOOR = 1.0


@dataclass
class State:
    precision: np.ndarray  # (P, 4, 4)
    b: np.ndarray  # (P, 4)
    nights: np.ndarray  # (P,)
    shown: np.ndarray | None = None  # (P,) bool: the insight showed after the last usable night
    week: np.ndarray | None = None  # (P,) int64: calendar week of the last usable night, −1 if none
    scale_sum: np.ndarray | None = None  # (P,) forgetting sum of squared standardized residuals
    scale_nights: np.ndarray | None = None  # (P,) forgetting count of the nights in it
    week_sum: np.ndarray | None = None  # (P,) this week's sum of standardized residuals
    week_nights: np.ndarray | None = None  # (P,) this week's usable nights
    last_week_sum: np.ndarray | None = None  # (P,) the week before's sum, 0 if that week had no night
    scale_cross: np.ndarray | None = None  # (P,) forgetting sum of each week's sum times the week before's

    def __post_init__(self) -> None:
        count = len(self.nights)
        if self.shown is None:
            self.shown = np.zeros(count, dtype=bool)
        if self.week is None:
            self.week = np.full(count, -1, dtype=np.int64)
        if self.scale_sum is None:
            self.scale_sum = np.zeros(count)
        if self.scale_nights is None:
            self.scale_nights = np.zeros(count)
        if self.week_sum is None:
            self.week_sum = np.zeros(count)
        if self.week_nights is None:
            self.week_nights = np.zeros(count)
        if self.last_week_sum is None:
            self.last_week_sum = np.zeros(count)
        if self.scale_cross is None:
            self.scale_cross = np.zeros(count)

    @property
    def people(self) -> int:
        return len(self.nights)

    def rows(self, which) -> "State":
        return State(
            self.precision[which], self.b[which], self.nights[which], self.shown[which],
            self.week[which], self.scale_sum[which], self.scale_nights[which],
            self.week_sum[which], self.week_nights[which], self.last_week_sum[which], self.scale_cross[which],
        )

    def person(self, i: int) -> dict:
        """One person's state as the app stores it: Λ row by row."""
        return {
            "precision": [float(v) for v in self.precision[i].reshape(-1)],
            "b": [float(v) for v in self.b[i]],
            "nights": int(self.nights[i]),
            "shown": bool(self.shown[i]),
            "week": None if self.week[i] < 0 else int(self.week[i]),
            "scale_sum": float(self.scale_sum[i]),
            "scale_nights": float(self.scale_nights[i]),
            "week_sum": float(self.week_sum[i]),
            "week_nights": float(self.week_nights[i]),
            "last_week_sum": float(self.last_week_sum[i]),
            "scale_cross": float(self.scale_cross[i]),
        }


def prior_precision(params: Params) -> np.ndarray:
    lam = np.zeros((N, N))
    for i in range(N):
        lam[i, i] = 1.0 / (params.prior_sd[i] * params.prior_sd[i])
    return lam


def prior_b(params: Params) -> np.ndarray:
    return np.array([params.prior_mean[i] / (params.prior_sd[i] * params.prior_sd[i]) for i in range(N)])


def prior_state(params: Params, people: int) -> State:
    return State(
        precision=np.repeat(prior_precision(params)[None], people, axis=0),
        b=np.repeat(prior_b(params)[None], people, axis=0),
        nights=np.zeros(people, dtype=np.int64),
    )


def dot(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Sum over the last axis, left to right."""
    acc = np.zeros(np.broadcast_shapes(a.shape, b.shape)[:-1])
    for i in range(N):
        acc = acc + a[..., i] * b[..., i]
    return acc


def base(params: Params, phi: np.ndarray) -> np.ndarray:
    return dot(np.broadcast_to(params.theta, phi.shape), phi)


def cholesky(lam: np.ndarray) -> np.ndarray:
    L = np.zeros_like(lam)
    for j in range(N):
        s = lam[..., j, j]
        for k in range(j):
            s = s - L[..., j, k] * L[..., j, k]
        L[..., j, j] = np.sqrt(s)
        for i in range(j + 1, N):
            s = lam[..., i, j]
            for k in range(j):
                s = s - L[..., i, k] * L[..., j, k]
            L[..., i, j] = s / L[..., j, j]
    return L


def forward(L: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Solves L x = v. L is (P, 4, 4); v is (P, 4) or (P, D, 4)."""
    extra = v.ndim - 2
    Lx = L.reshape(L.shape[:1] + (1,) * extra + L.shape[1:])
    x = np.zeros_like(v)
    for i in range(N):
        s = v[..., i]
        for k in range(i):
            s = s - Lx[..., i, k] * x[..., k]
        x[..., i] = s / Lx[..., i, i]
    return x


def backward(L: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Solves Lᵀ x = v."""
    extra = v.ndim - 2
    Lx = L.reshape(L.shape[:1] + (1,) * extra + L.shape[1:])
    x = np.zeros_like(v)
    for i in range(N - 1, -1, -1):
        s = v[..., i]
        for k in range(i + 1, N):
            s = s - Lx[..., k, i] * x[..., k]
        x[..., i] = s / Lx[..., i, i]
    return x


def mean(L: np.ndarray, b: np.ndarray) -> np.ndarray:
    return backward(L, forward(L, b))


def scale2(state: State, params: Params) -> np.ndarray:
    """κ² for each person, the current week included: 1 until the artifact learns the noise's scale."""
    a0 = params.noise_scale_prior_nights
    if a0 <= 0:
        return np.ones(state.people)
    t = state.week_sum
    squares = state.scale_sum + t * t
    cross = state.scale_cross + t * state.last_week_sum
    k2 = (a0 + (squares + np.maximum(cross, 0.0))) / (a0 + (state.scale_nights + state.week_nights))
    return np.maximum(k2, SCALE_FLOOR)


def effective(state: State, params: Params) -> tuple[np.ndarray, np.ndarray]:
    """The precision and b every range is drawn from: Λ/κ² and b/κ², so μ is the same and Σ is κ²Σ."""
    if params.noise_scale_prior_nights <= 0:
        return state.precision, state.b
    k2 = scale2(state, params)
    return state.precision / k2[:, None, None], state.b / k2[:, None]


def wander(lam: np.ndarray, b: np.ndarray, weeks: np.ndarray, params: Params) -> tuple[np.ndarray, np.ndarray]:
    """Σ + q·e₀e₀ᵀ with μ kept, in information form: Λ − g·c·cᵀ and b − g·c·b₀, with c Λ's first
    column and g = q / (1 + q·Λ₀₀). q is `intercept_week_sd`² per week passed; 0 changes nothing."""
    sd = params.intercept_week_sd
    q = sd * sd * weeks
    g = q / (1.0 + q * lam[:, 0, 0])
    c = lam[:, :, 0].copy()
    b0 = b[:, 0].copy()
    lam = lam.copy()
    b = b.copy()
    for i in range(N):
        for j in range(N):
            lam[:, i, j] = lam[:, i, j] - g * c[:, i] * c[:, j]
        b[:, i] = b[:, i] - g * c[:, i] * b0
    return lam, b


def update(
    state: State,
    phi: np.ndarray,
    y: np.ndarray,
    usable: np.ndarray,
    params: Params,
    week: np.ndarray | None = None,
) -> None:
    """One night for everyone: only rows where `usable` is true change. `week` is each night's
    calendar week (`timing.week_of`), −1 for a night without a date; the intercept wanders only
    between two known weeks."""
    s2 = params.noise_sd * params.noise_sd
    clip = params.residual_clip_min
    r = np.clip(y - base(params, phi), -clip, clip)
    lam = state.precision.copy()
    b = state.b.copy()
    if params.forgetting < 1.0:
        lam0, b0 = prior_precision(params), prior_b(params)
        lam = lam0 + params.forgetting * (lam - lam0)
        b = b0 + params.forgetting * (b - b0)
    week = np.full(state.people, -1, dtype=np.int64) if week is None else np.asarray(week, dtype=np.int64)
    known = (week >= 0) & (state.week >= 0)
    if params.intercept_week_sd > 0:
        passed = np.where(known, np.maximum(week - state.week, 0), 0).astype(float)
        lam, b = wander(lam, b, passed, params)
    scale_sum, scale_nights = state.scale_sum, state.scale_nights
    week_sum, week_nights = state.week_sum, state.week_nights
    last_week_sum, scale_cross = state.last_week_sum, state.scale_cross
    if params.noise_scale_prior_nights > 0:
        new = known & (week > state.week)
        scale_sum = params.forgetting * (scale_sum + np.where(new, week_sum * week_sum, 0.0))
        scale_cross = params.forgetting * (scale_cross + np.where(new, week_sum * last_week_sum, 0.0))
        scale_nights = params.forgetting * (scale_nights + np.where(new, week_nights, 0.0))
        last_week_sum = np.where(new, np.where(week - state.week == 1, week_sum, 0.0), last_week_sum)
        L = cholesky(lam)
        e = r - dot(phi, mean(L, b))
        v = forward(L, phi)
        week_sum = np.where(new, 0.0, week_sum) + e / np.sqrt(dot(v, v) + s2)
        week_nights = np.where(new, 0.0, week_nights) + 1.0
    for i in range(N):
        for j in range(N):
            lam[:, i, j] = lam[:, i, j] + (phi[:, i] * phi[:, j]) / s2
        b[:, i] = b[:, i] + (phi[:, i] * r) / s2
    state.precision = np.where(usable[:, None, None], lam, state.precision)
    state.b = np.where(usable[:, None], b, state.b)
    state.nights = state.nights + usable.astype(np.int64)
    state.week = np.where(usable & (week >= 0), week, state.week)
    state.scale_sum = np.where(usable, scale_sum, state.scale_sum)
    state.scale_nights = np.where(usable, scale_nights, state.scale_nights)
    state.week_sum = np.where(usable, week_sum, state.week_sum)
    state.week_nights = np.where(usable, week_nights, state.week_nights)
    state.last_week_sum = np.where(usable, last_week_sum, state.last_week_sum)
    state.scale_cross = np.where(usable, scale_cross, state.scale_cross)
    from .insights import shown  # insights reads this module

    state.shown = np.where(usable, shown(state, params)[0], state.shown)


def predict(state: State, phi: np.ndarray, params: Params) -> tuple[np.ndarray, np.ndarray]:
    """Mean f + φᵀμ and sd √(κ²(φᵀΣφ + σ²)) of the onset, in minutes from planned bedtime."""
    lam, b = effective(state, params)
    L = cholesky(lam)
    mu = mean(L, b)
    m = base(params, phi) + dot(phi, mu)
    v = forward(L, phi)
    return m, np.sqrt(dot(v, v) + scale2(state, params) * (params.noise_sd * params.noise_sd))
