"""The per-person adapter on a frozen base, for many people at once.

Every operation is written out in a fixed order (no LAPACK), so the Swift package, which does the same
steps one person at a time, gives the same numbers to rounding.

State per person: the precision matrix Λ (4×4), the vector b (4) and the count of usable nights.
μ = Λ⁻¹ b and Σ = Λ⁻¹ come from the Cholesky factor L of Λ.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .artifact import Params

N = 4


@dataclass
class State:
    precision: np.ndarray  # (P, 4, 4)
    b: np.ndarray  # (P, 4)
    nights: np.ndarray  # (P,)

    @property
    def people(self) -> int:
        return len(self.nights)

    def person(self, i: int) -> dict:
        """One person's state as the app stores it: Λ row by row."""
        return {
            "precision": [float(v) for v in self.precision[i].reshape(-1)],
            "b": [float(v) for v in self.b[i]],
            "nights": int(self.nights[i]),
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


def update(state: State, phi: np.ndarray, y: np.ndarray, usable: np.ndarray, params: Params) -> None:
    """One night for everyone: only rows where `usable` is true change."""
    s2 = params.noise_sd * params.noise_sd
    clip = params.residual_clip_min
    r = np.clip(y - base(params, phi), -clip, clip)
    lam = state.precision.copy()
    b = state.b.copy()
    if params.forgetting < 1.0:
        lam0, b0 = prior_precision(params), prior_b(params)
        lam = lam0 + params.forgetting * (lam - lam0)
        b = b0 + params.forgetting * (b - b0)
    for i in range(N):
        for j in range(N):
            lam[:, i, j] = lam[:, i, j] + (phi[:, i] * phi[:, j]) / s2
        b[:, i] = b[:, i] + (phi[:, i] * r) / s2
    state.precision = np.where(usable[:, None, None], lam, state.precision)
    state.b = np.where(usable[:, None], b, state.b)
    state.nights = state.nights + usable.astype(np.int64)


def predict(state: State, phi: np.ndarray, params: Params) -> tuple[np.ndarray, np.ndarray]:
    """Mean f + φᵀμ and sd √(φᵀΣφ + σ²) of the onset, in minutes from planned bedtime."""
    L = cholesky(state.precision)
    mu = mean(L, state.b)
    m = base(params, phi) + dot(phi, mu)
    v = forward(L, phi)
    return m, np.sqrt(dot(v, v) + params.noise_sd * params.noise_sd)
