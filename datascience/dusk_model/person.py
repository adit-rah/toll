"""One person, with the same calls as the Swift `SleepModel`. Used by replay and the fixtures."""

from __future__ import annotations

import numpy as np

from . import insights as insight_rules
from .artifact import Params
from .model import State, predict, prior_state, update
from .night import Context, features, latest, phi
from .policy import choose_one
from .rng import SplitMix64Batch


class SeededRNG:
    """A single SplitMix64 stream in the shape the policy takes."""

    def __init__(self, seed: int):
        self.batch = SplitMix64Batch(np.array([seed], dtype=np.uint64))

    @property
    def state(self) -> int:
        return int(self.batch.state[0])


class PersonModel:
    def __init__(self, params: Params, state: dict | None = None):
        self.params = params
        self._state = prior_state(params, 1)
        if state is not None:
            self._state.precision[0] = np.array(state["precision"], dtype=float).reshape(4, 4)
            self._state.b[0] = np.array(state["b"], dtype=float)
            self._state.nights[0] = int(state["nights"])

    @property
    def state(self) -> dict:
        return self._state.person(0)

    def update(self, record: dict) -> tuple[bool, str | None]:
        """False, with the reason, if the night was skipped."""
        f = features(record, self.params)
        update(
            self._state,
            phi(f.offset, f.context)[None, :],
            np.array([f.y]),
            np.array([f.usable]),
            self.params,
        )
        return f.usable, f.skip

    def predict(self, context: Context, offset: int) -> tuple[float, float]:
        m, sd = predict(self._state, phi(offset, context)[None, :], self.params)
        return float(m[0]), float(sd[0])

    def choose_offset(
        self, context: Context, rng: SeededRNG, allowed: list[int] | None = None
    ) -> tuple[int, float]:
        allowed = list(self.params.actions) if allowed is None else allowed
        return choose_one(self._state, context, allowed, rng.batch, self.params)

    def insights(self) -> list[dict]:
        return insight_rules.insights(self._state, self.params)


def rebuild(params: Params, records: list[dict]) -> PersonModel:
    """A person's state from their whole night log, as the app rebuilds it when a new artifact ships:
    each night once, at its highest revision, in night order."""
    person = PersonModel(params)
    for record in latest(records):
        person.update(record)
    return person
