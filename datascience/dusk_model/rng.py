"""Seeded random numbers that Swift reproduces draw for draw.

SplitMix64 for 64-bit integers, the top 53 bits for uniforms, Box–Muller (cosine branch only) for
normals. Swift's own generator cannot be seeded, so both sides carry this one.

SplitMix64's n-th output depends only on seed + n * GOLDEN, so a whole block of draws is made at once
with numpy instead of a Python loop. `SplitMix64` keeps the position so blocks follow each other.
"""

from __future__ import annotations

import numpy as np

MASK = (1 << 64) - 1
GOLDEN = 0x9E3779B97F4A7C15
_M1 = np.uint64(0xBF58476D1CE4E5B9)
_M2 = np.uint64(0x94D049BB133111EB)
_TWO_PI = 6.283185307179586
_INV_2_53 = 1.0 / 9007199254740992.0


def _mix(z: np.ndarray) -> np.ndarray:
    with np.errstate(over="ignore"):
        z = (z ^ (z >> np.uint64(30))) * _M1
        z = (z ^ (z >> np.uint64(27))) * _M2
    return z ^ (z >> np.uint64(31))


class SplitMix64:
    """One stream per person. `state` is the raw 64-bit state, as Swift stores it."""

    def __init__(self, seed: int):
        self.state = seed & MASK

    def u64(self, n: int) -> np.ndarray:
        steps = np.arange(1, n + 1, dtype=np.uint64)
        with np.errstate(over="ignore"):
            states = np.uint64(self.state) + steps * np.uint64(GOLDEN)
        self.state = (self.state + n * GOLDEN) & MASK
        return _mix(states)

    def uniform(self, n: int) -> np.ndarray:
        """In [0, 1)."""
        return (self.u64(n) >> np.uint64(11)).astype(np.float64) * _INV_2_53

    def normal(self, n: int) -> np.ndarray:
        """Each normal takes two uniforms: u1 in (0, 1] so the log is finite, then u2."""
        u = self.uniform(2 * n).reshape(n, 2)
        u1 = 1.0 - u[:, 0]
        return np.sqrt(-2.0 * np.log(u1)) * np.cos(_TWO_PI * u[:, 1])


class SplitMix64Batch:
    """Many independent streams advanced together, for the simulator."""

    def __init__(self, seeds: np.ndarray):
        self.state = np.asarray(seeds, dtype=np.uint64).copy()

    def uniform(self, n: int) -> np.ndarray:
        steps = np.arange(1, n + 1, dtype=np.uint64)
        with np.errstate(over="ignore"):
            states = self.state[:, None] + steps[None, :] * np.uint64(GOLDEN)
            self.state = self.state + np.uint64(n) * np.uint64(GOLDEN)
        return (_mix(states) >> np.uint64(11)).astype(np.float64) * _INV_2_53

    def normal(self, n: int) -> np.ndarray:
        u = self.uniform(2 * n).reshape(len(self.state), n, 2)
        u1 = 1.0 - u[..., 0]
        return np.sqrt(-2.0 * np.log(u1)) * np.cos(_TWO_PI * u[..., 1])
