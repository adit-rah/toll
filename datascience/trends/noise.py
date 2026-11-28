"""Nights for the trend study: a person's weekly level that wanders, and heavy-tailed nights around it.

A night's value (minutes) is the week's level plus the night's own noise:
- **The level** is an AR(1) from week to week with stationary spread `wander` and lag-one memory
  `memory`. With `wander` 0 the person never changes: the null.
- **The night** is a contaminated normal: most nights `core` minutes either side, a share `share` of
  them `outlier` minutes (a late night out, a nap counted as the night, a missed watch). `share` 0 is
  Gaussian.
- A night is missing with chance `missing`.

`measure` gives the aggregates a Health export is described by (spread within a week, the share of
nights far from their week's median, the median change from one night to the next, and the spread and
memory of the weekly median), so `calibrate` can fit a profile to aggregates kept outside this repo:

    uv run python -m trends.noise calibrate --aggregates path/to/aggregates.json --out profiles.json

The public study runs a grid of profiles (`GRID`) that brackets heavy tails and long memory; a real
export's own profile is passed with `--profiles` and its results stay with it.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass, replace
from pathlib import Path

import numpy as np


@dataclass(frozen=True)
class Profile:
    core: float
    share: float = 0.0
    outlier: float = 0.0
    wander: float = 0.0
    memory: float = 0.0
    missing: float = 0.0

    def still(self) -> Profile:
        """The same nights with no change in level."""
        return replace(self, wander=0.0)


# Public stress profiles: the simulator's nights (E-006), wide Gaussian nights, and heavy tails, each
# with a short and a long memory of the level. None of them is a person's export.
GRID: dict[str, Profile] = {
    "sim": Profile(core=30.0, wander=15.0, memory=0.85),
    "gauss-20": Profile(core=20.0, wander=40.0, memory=0.95, missing=0.02),
    "gauss-45": Profile(core=45.0, wander=40.0, memory=0.95, missing=0.05),
    "heavy-40": Profile(core=40.0, share=0.2, outlier=180.0, wander=50.0, memory=0.3, missing=0.05),
    "heavy-70": Profile(core=70.0, share=0.25, outlier=240.0, wander=80.0, memory=0.4, missing=0.1),
}


def levels(profile: Profile, people: int, weeks: int, gen: np.random.Generator) -> np.ndarray:
    """(people, weeks) weekly levels, stationary from the first week."""
    out = np.zeros((people, weeks))
    if profile.wander <= 0:
        return out
    phi = profile.memory
    step = profile.wander * np.sqrt(max(0.0, 1.0 - phi * phi))
    out[:, 0] = gen.normal(0.0, profile.wander, people)
    for w in range(1, weeks):
        out[:, w] = phi * out[:, w - 1] + gen.normal(0.0, step, people)
    return out


def night_noise(profile: Profile, shape: tuple[int, ...], gen: np.random.Generator) -> np.ndarray:
    core = gen.normal(0.0, profile.core, shape)
    if profile.share <= 0:
        return core
    wild = gen.random(shape) < profile.share
    return np.where(wild, gen.normal(0.0, profile.outlier, shape), core)


def nights(
    profile: Profile, people: int, weeks: int, gen: np.random.Generator, shuffle: bool = False
) -> tuple[np.ndarray, np.ndarray]:
    """(values, levels): values (people, weeks*7) with NaN for missing nights, and each night's level.

    `shuffle` puts each person's nights in a random order: the replay's null, where the level's moves
    become night noise and nothing changes over time.
    """
    level = np.repeat(levels(profile, people, weeks, gen), 7, axis=1)
    values = level + night_noise(profile, level.shape, gen)
    if shuffle:
        order = np.argsort(gen.random(values.shape), axis=1)
        values = np.take_along_axis(values, order, axis=1)
        level = np.zeros_like(level)
    values[gen.random(values.shape) < profile.missing] = np.nan
    return values, level


def measure(values: np.ndarray, far: float = 90.0) -> dict:
    """The aggregates of one person's nights (weeks*7, NaN missing), as an export is described."""
    weeks = values.reshape(-1, 7)
    sds, far_count, count, medians = [], 0, 0, []
    for week in weeks:
        v = week[~np.isnan(week)]
        if len(v) < 3:
            medians.append(np.nan)
            continue
        sds.append(np.var(v, ddof=1))
        m = np.median(v)
        medians.append(m)
        far_count += int((np.abs(v - m) > far).sum())
        count += len(v)
    seen = values[~np.isnan(values)]
    med = np.array(medians)
    med = med[~np.isnan(med)]
    centred = med - med.mean()
    ar = float((centred[1:] * centred[:-1]).sum() / (centred * centred).sum()) if len(med) > 2 else 0.0
    return {
        "within_sd": float(np.sqrt(np.mean(sds))) if sds else 0.0,
        "far_share": far_count / max(1, count),
        "median_change": float(np.median(np.abs(np.diff(seen)))) if len(seen) > 1 else 0.0,
        "weekly_sd": float(med.std(ddof=1)) if len(med) > 1 else 0.0,
        "weekly_ar": ar,
    }


def expected(profile: Profile, weeks: int, people: int = 400, seed: int = 7) -> dict:
    """The aggregates a profile gives on average over people with `weeks` weeks each."""
    gen = np.random.default_rng(seed)
    values, _ = nights(profile, people, weeks, gen)
    rows = [measure(v) for v in values]
    return {k: float(np.mean([r[k] for r in rows])) for k in rows[0]}


KEYS = ("within_sd", "far_share", "median_change", "weekly_sd", "weekly_ar")
SCALE = {"within_sd": 10.0, "far_share": 0.03, "median_change": 8.0, "weekly_sd": 8.0, "weekly_ar": 0.08}


def calibrate(target: dict, seed: int = 11) -> Profile:
    """A profile whose expected aggregates match `target`: a grid over the night's shape, then a local
    search over every number. The loss is on common random numbers, so it is deterministic."""
    weeks = int(target["weeks"])
    gaussian = bool(target.get("gaussian", False))
    missing = max(0.0, 1.0 - target.get("nights", weeks * 7) / (weeks * 7))
    keys = [k for k in KEYS if k in target and not (gaussian and k in ("far_share", "median_change"))]
    sd = float(target["within_sd"])

    def loss(p: Profile) -> float:
        got = expected(p, weeks, people=120, seed=seed)
        return sum(((got[k] - target[k]) / SCALE[k]) ** 2 for k in keys)

    base = Profile(core=sd, wander=target["weekly_sd"], memory=target["weekly_ar"], missing=missing)
    starts = [base]
    if not gaussian:
        starts = [
            replace(base, core=sd * c, share=q, outlier=sd * o)
            for c in (0.3, 0.4, 0.5) for q in (0.2, 0.3, 0.4) for o in (1.5, 1.8, 2.1)
        ]
    best = min(starts, key=loss)
    best_loss = loss(best)
    # Gaussian nights' spread within a week is the core itself; only the level is searched.
    steps = {"wander": 0.2, "memory": 0.08}
    if not gaussian:
        steps |= {"core": 0.15, "share": 0.05, "outlier": 0.15}
    for _ in range(8):
        improved = False
        for name, step in steps.items():
            for sign in (1, -1):
                v = getattr(best, name)
                new = v + sign * step if name in ("share", "memory") else v * (1 + sign * step)
                new = min(max(new, 0.0), 0.995 if name == "memory" else 0.6 if name == "share" else 1e4)
                cand = replace(best, **{name: new})
                cl = loss(cand)
                if cl < best_loss:
                    best, best_loss, improved = cand, cl, True
        if not improved:
            steps = {k: v / 2 for k, v in steps.items()}
    return best


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    cal = sub.add_parser("calibrate")
    cal.add_argument("--aggregates", required=True)
    cal.add_argument("--out", required=True)
    args = ap.parse_args()
    targets = json.loads(Path(args.aggregates).read_text())
    out = {}
    for name, target in targets.items():
        p = calibrate(target)
        out[name] = {"profile": asdict(p), "expected": expected(p, int(target["weeks"])), "target": target}
        print(name, out[name])
    Path(args.out).write_text(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
