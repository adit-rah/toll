"""Choosing tonight's block start for people who opted in: Thompson sampling with a floor.

The chance each start would win is estimated from `prob_draws` draws of w ~ N(μ, Σ). Mixing that with
a uniform choice, p' = (1 − K·floor)·p + floor, guarantees every allowed start at least the floor. One
more uniform then picks the start from p', so the logged chance is exactly the one used.

Every call takes the same number of draws (4 normals per draw, then one uniform) whatever is allowed,
so a person's stream stays in step with Swift's.
"""

from __future__ import annotations

import numpy as np

from .artifact import Params
from .model import State, backward, base, cholesky, dot, mean
from .night import Context
from .rng import SplitMix64Batch


def features_for(params: Params, weekend: np.ndarray, late: np.ndarray) -> np.ndarray:
    """(P, K, 4): φ for each person and each action in the artifact's order."""
    people, actions = len(weekend), len(params.actions)
    phi = np.empty((people, actions, 4))
    phi[..., 0] = 1.0
    phi[..., 1] = np.array([a / 30.0 for a in params.actions])[None, :]
    phi[..., 2] = weekend.astype(float)[:, None]
    phi[..., 3] = late.astype(float)[:, None]
    return phi


def win_probabilities(
    state: State, phi: np.ndarray, allowed: np.ndarray, rng: SplitMix64Batch, params: Params
) -> np.ndarray:
    """(P, K): share of draws in which each allowed action predicts the earliest sleep."""
    draws = params.prob_draws
    L = cholesky(state.precision)
    mu = mean(L, state.b)
    z = rng.normal(draws * 4).reshape(state.people, draws, 4)
    w = mu[:, None, :] + backward(L, z)
    counts = np.zeros(phi.shape[:2])
    best = np.full((state.people, draws), np.inf)
    pick = np.zeros((state.people, draws), dtype=np.int64)
    for k in range(phi.shape[1]):
        f = base(params, phi[:, k, :])[:, None]
        pred = f + dot(phi[:, None, k, :], w)
        better = allowed[:, k][:, None] & (pred < best)
        best = np.where(better, pred, best)
        pick = np.where(better, k, pick)
    for k in range(phi.shape[1]):
        counts[:, k] = (pick == k).sum(axis=1)
    return counts / float(draws)


def choose(
    state: State,
    weekend: np.ndarray,
    late: np.ndarray,
    allowed: np.ndarray,
    rng: SplitMix64Batch,
    params: Params,
) -> tuple[np.ndarray, np.ndarray]:
    """Returns each person's offset in minutes and the chance it had."""
    phi = features_for(params, weekend, late)
    p = win_probabilities(state, phi, allowed, rng, params)
    k_allowed = allowed.sum(axis=1).astype(float)
    floor = params.min_prob
    mixed = np.where(allowed, (1.0 - k_allowed[:, None] * floor) * p + floor, 0.0)
    single = k_allowed == 1
    mixed = np.where(single[:, None], allowed.astype(float), mixed)
    u = rng.uniform(1)[:, 0]
    actions = np.array(params.actions)
    chosen = np.full(state.people, -1)
    cumulative = np.zeros(state.people)
    for k in range(len(actions)):
        cumulative = cumulative + mixed[:, k]
        take = (chosen < 0) & allowed[:, k] & (u < cumulative)
        chosen = np.where(take, k, chosen)
    last_allowed = np.array([np.flatnonzero(row)[-1] for row in allowed])
    chosen = np.where(chosen < 0, last_allowed, chosen)
    rows = np.arange(state.people)
    return actions[chosen], mixed[rows, chosen]


def choose_one(
    state: State, context: Context, allowed: list[int], rng: SplitMix64Batch, params: Params
) -> tuple[int, float]:
    mask = np.array([[a in allowed for a in params.actions]])
    if not mask.any():
        mask = np.array([[a == 0 for a in params.actions]])
    offset, prob = choose(
        state, np.array([context.weekend]), np.array([context.late]), mask, rng, params
    )
    return int(offset[0]), float(prob[0])
