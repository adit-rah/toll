"""The grid of how much a person's usual time moves (`sim.wander` lays them over a scenario's nights).

Invented to bracket people's usual time; their range was checked against a real Health export (n=1,
private), and none of them is that export. Each is a weekly level, an AR(1) across calendar weeks with
sd `level` minutes and correlation `memory` from one week to the next, and optionally a share `tail` of
nights drawn with sd `tail_sd` in place of the simulator's own nightly noise. The name says it:
`l90-r0.2-t40-240` is level sd 90, memory 0.2, 40% of nights with sd 240. The corners of level and
memory are in, with and without heavy tails. Kept apart from `sim.wander` so `sim.criteria` can name
them without importing the simulator's worlds.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Profile:
    level: float
    memory: float
    tail: float = 0.0
    tail_sd: float = 0.0

    @property
    def name(self) -> str:
        out = f"l{self.level:g}-r{self.memory:g}"
        return out + (f"-t{self.tail * 100:g}-{self.tail_sd:g}" if self.tail else "")


GRID = [
    Profile(20.0, 0.2),
    Profile(20.0, 0.97),
    Profile(45.0, 0.6),
    Profile(90.0, 0.2),
    Profile(90.0, 0.97),
    Profile(45.0, 0.6, tail=0.15, tail_sd=150.0),
    Profile(20.0, 0.97, tail=0.4, tail_sd=150.0),
    Profile(90.0, 0.2, tail=0.4, tail_sd=240.0),
    Profile(90.0, 0.97, tail=0.15, tail_sd=240.0),
]
PROFILES = {p.name: p for p in GRID}
