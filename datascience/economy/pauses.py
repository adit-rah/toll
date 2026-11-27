"""The pause economy (#61, D67, D70): how today's numbers (3 pauses a week, back each Monday, a 60 s wait,
10 minutes open) behave across simulated people, and which unknowns decide whether to change them.

    uv run python -m economy.pauses grid --people 4000 --out reports/pauses-grid.json
    uv run python -m economy.pauses sensitivity --people 4000 --out reports/pauses-sensitivity.json
    uv run python -m economy.pauses power --people 4000 --out reports/pauses-power.json

Nothing here is measured. Dusk has no night records from real people yet, so every behaviour below is an
assumption, written down in `Behaviour` and varied in the sensitivity run. Only the night's own block is
simulated; day blocks share the pool (D55) and would only make the cap bind sooner.

**A night.** The lock is on for `lock_min` minutes on nights at home. A person wants a pause at moments
that arrive at random (Poisson, `urges` a night, different for each person). With a pause left, they start
the wait; they see it through with chance exp(−wait / patience), else they cancel, which costs nothing
(D-3). A pause opens every block for `minutes`; a want that comes while it's open is met by it. With none
left, the want is refused, and with chance `off_per_refusal` they switch Screen Time off for the rest of
the night; a share `quit_share` of those leave it off for good. Two assumptions are off in the base run and
tried in the sensitivity run: that wants grow with the pauses on offer, and that a cancelled wait itself
sometimes ends in a switch-off.

**Measured** (per person-week unless named): pauses used, waits cancelled, weeks the pauses ran out,
wants refused, weeks with Screen Time switched off, people gone by the end, and minutes unshielded a lock
night (open pauses, plus the rest of a night after a switch-off, plus whole nights once gone).
"""

from __future__ import annotations

import argparse
import json
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np


@dataclass(frozen=True)
class Economy:
    """The numbers in `TollConfig.unlocks` and `TollConfig.door`, and how pauses come back."""

    per_week: int = 3
    wait_s: int = 60
    minutes: int = 10
    refill: str = "weekly"  # "weekly": back to per_week each Monday; "nightly": also at most 1 a night


@dataclass(frozen=True)
class Behaviour:
    """Assumptions, every one of them."""

    urges_median: float = 0.3  # wants of a pause per lock night, the median person
    urges_sd: float = 1.0  # log-scale spread between people: a quarter want twice the median or more
    patience_median_s: float = 120.0  # exp(−wait / patience): seeing a 60 s wait through is 61% at the median
    patience_sd: float = 0.5
    off_per_refusal: float = 0.10
    quit_share: float = 0.3
    off_background: float = 0.005  # a lock night switched off for other reasons: about 3.4% of weeks
    supply_elasticity: float = 0.0  # wants scale with (pauses a week / 3) to this power: 1 = more pauses, more wants
    off_per_wait_min: float = 0.0  # a cancelled wait switches Screen Time off with this chance per minute waited
    home: float = 0.9
    lock_min: int = 585  # 8 h 30 m of sleep, 30 min before and 15 after (D97's starts)


@dataclass
class Result:
    used: np.ndarray  # (P, weeks)
    cancelled: np.ndarray
    refused: np.ndarray
    ran_out: np.ndarray
    off: np.ndarray
    unshielded: np.ndarray  # (P, nights) minutes
    paused_min: np.ndarray  # (P, nights) of those, minutes a pause was open
    locked: np.ndarray  # (P, nights) lock nights, gone or not
    gone: np.ndarray  # (P,)


def simulate(e: Economy, b: Behaviour, people: int, nights: int, seed: int) -> Result:
    gen = np.random.default_rng([seed, 61])
    weeks = -(-nights // 7)
    lam = b.urges_median * (e.per_week / 3) ** b.supply_elasticity * np.exp(b.urges_sd * gen.standard_normal(people))
    patience = b.patience_median_s * np.exp(b.patience_sd * gen.standard_normal(people))
    see_through = np.exp(-e.wait_s / patience)
    out = {k: np.zeros((people, weeks)) for k in ("used", "cancelled", "refused", "ran_out", "off")}
    unshielded = np.zeros((people, nights))
    paused_min = np.zeros((people, nights))
    locked = np.zeros((people, nights), dtype=bool)
    gone = np.zeros(people, dtype=bool)
    left = np.zeros(people)
    for t in range(nights):
        week = t // 7
        if t % 7 == 0:
            left[:] = e.per_week
        lock = gen.random(people) < b.home
        locked[:, t] = lock
        unshielded[:, t] = np.where(lock & gone, b.lock_min, 0.0)
        active = lock & ~gone
        count = gen.poisson(lam) * active
        most = int(count.max()) if count.size else 0
        times = np.sort(np.where(np.arange(most)[None, :] < count[:, None], gen.random((people, most)) * b.lock_min, np.inf), axis=1)
        open_until = np.full(people, -np.inf)
        tonight = np.zeros(people)
        switched = np.zeros(people, dtype=bool)
        for k in range(most):
            at = times[:, k]
            want = np.isfinite(at) & ~switched & (at >= open_until)
            can = want & (left > 0) & ((e.refill != "nightly") | (tonight < 1))
            through = can & (gen.random(people) < see_through)
            out["cancelled"][:, week] += can & ~through
            annoyed = can & ~through & (gen.random(people) < b.off_per_wait_min * e.wait_s / 60.0)
            unshielded[:, t] += np.where(annoyed, b.lock_min - at, 0.0)
            switched |= annoyed
            opened = at + e.wait_s / 60.0
            open_until = np.where(through, opened + e.minutes, open_until)
            open_min = np.where(through, np.clip(b.lock_min - opened, 0.0, e.minutes), 0.0)
            unshielded[:, t] += open_min
            paused_min[:, t] += open_min
            left -= through
            tonight += through
            out["used"][:, week] += through
            refused = want & ~can
            out["refused"][:, week] += refused
            off = refused & (gen.random(people) < b.off_per_refusal)
            unshielded[:, t] += np.where(off, b.lock_min - at, 0.0)
            switched |= off
            quit_now = off & (gen.random(people) < b.quit_share)
            gone |= quit_now
        other = active & ~switched & (gen.random(people) < b.off_background)
        unshielded[:, t] += np.where(other, b.lock_min / 2, 0.0)
        switched |= other
        out["off"][:, week] = np.maximum(out["off"][:, week], switched)
        out["ran_out"][:, week] = np.maximum(out["ran_out"][:, week], left <= 0)
    return Result(**out, unshielded=unshielded, paused_min=paused_min, locked=locked, gone=gone)


def summary(r: Result, nights: int) -> dict:
    weeks = r.used.shape[1]
    lock_nights = r.locked.sum()
    per_week = lambda a: float(a.sum() / (a.shape[0] * weeks))  # noqa: E731
    return {
        "pauses_used_per_week": per_week(r.used),
        "waits_cancelled_per_week": per_week(r.cancelled),
        "weeks_ran_out": float(r.ran_out.mean()),
        "people_ever_ran_out": float(r.ran_out.any(axis=1).mean()),
        "refused_per_week": per_week(r.refused),
        "weeks_screen_time_off": float(r.off.mean()),
        "gone_by_end": float(r.gone.mean()),
        "unshielded_min_per_lock_night": float(r.unshielded.sum() / max(1, lock_nights)),
        "paused_min_per_lock_night": float(r.paused_min.sum() / max(1, lock_nights)),
        "nights": nights,
    }


GRID = [
    Economy(per_week=s, wait_s=w, minutes=m, refill=f)
    for s in (2, 3, 4, 5)
    for w in (30, 60, 120)
    for m in (5, 10, 15)
    for f in ("weekly", "nightly")
]

SENSITIVITY = {
    "base": Behaviour(),
    "fewer wants (0.15)": Behaviour(urges_median=0.15),
    "more wants (0.6)": Behaviour(urges_median=0.6),
    "wider spread (sd 1.4)": Behaviour(urges_sd=1.4),
    "impatient (60 s)": Behaviour(patience_median_s=60.0),
    "patient (300 s)": Behaviour(patience_median_s=300.0),
    "refusals rarely end it (0.03)": Behaviour(off_per_refusal=0.03),
    "refusals often end it (0.3)": Behaviour(off_per_refusal=0.3),
    "more pauses, more wants (elasticity 1)": Behaviour(supply_elasticity=1.0),
    "waiting annoys (0.05 a minute)": Behaviour(off_per_wait_min=0.05),
}
CANDIDATES = [
    Economy(),
    Economy(per_week=2),
    Economy(per_week=4),
    Economy(per_week=5),
    Economy(wait_s=30),
    Economy(wait_s=120),
    Economy(minutes=5),
    Economy(minutes=15),
    Economy(refill="nightly"),
]


def label(e: Economy) -> str:
    return f"{e.per_week}/wk · {e.wait_s}s · {e.minutes}min · {e.refill}"


def power(people: int, seed: int) -> dict:
    """How many person-weeks of real night records the questions need, from the base run's rates.

    Each person gives several weeks that are alike, so person-weeks count less than independent ones; the
    design effect uses the simulated people's own week-to-week correlation of running out."""
    r = simulate(Economy(), Behaviour(), people, 84, seed)
    ran = r.ran_out
    p = float(ran.mean())
    per_person = ran.mean(axis=1)
    weeks = ran.shape[1]
    # Intraclass correlation from the between-person variance of each person's share.
    between = per_person.var(ddof=1) - p * (1 - p) / weeks
    icc = max(0.0, between / (p * (1 - p))) if 0 < p < 1 else 0.0
    deff = 1 + (weeks - 1) * icc
    z = 1.96
    share_pm5 = z * z * p * (1 - p) / 0.05**2 * deff
    # Screen Time switched off in weeks that ran out against weeks that didn't: detect the simulated gap.
    off = r.off
    p1 = float(off[ran.astype(bool)].mean()) if ran.any() else 0.0
    p0 = float(off[~ran.astype(bool)].mean())
    zb = 0.84
    # The question for the pilot: are switch-offs at least twice as common in weeks the pauses ran out?
    # Sized for a doubling of the other weeks' rate, not the simulated gap, which is an assumption.
    q0, q1 = p0, 2 * p0
    off_weeks = ((z + zb) ** 2 * (q1 * (1 - q1) + q0 * (1 - q0)) / max((q1 - q0) ** 2, 1e-9)) * deff
    return {
        "ran_out_share": p,
        "icc": icc,
        "design_effect_12_weeks": deff,
        "person_weeks_for_ran_out_share_pm5": share_pm5,
        "people_at_12_weeks_for_ran_out_share": share_pm5 / 12,
        "off_share_weeks_ran_out": p1,
        "off_share_other_weeks": p0,
        "ran_out_weeks_needed_each_side": off_weeks,
        "person_weeks_for_off_difference": off_weeks / max(p, 1e-9),
        "people_at_12_weeks_for_off_difference": off_weeks / max(p, 1e-9) / 12,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("part", choices=["grid", "sensitivity", "power"])
    ap.add_argument("--people", type=int, default=4000)
    ap.add_argument("--nights", type=int, default=56)
    ap.add_argument("--seed", type=int, default=61)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    started = time.time()
    if args.part == "grid":
        rows = {label(e): summary(simulate(e, Behaviour(), args.people, args.nights, args.seed), args.nights) | {"economy": asdict(e)} for e in GRID}
    elif args.part == "sensitivity":
        rows = {
            name: {label(e): summary(simulate(e, b, args.people, args.nights, args.seed), args.nights) for e in CANDIDATES}
            for name, b in SENSITIVITY.items()
        }
    else:
        rows = power(args.people, args.seed)
    out = {"people": args.people, "nights": args.nights, "seed": args.seed, "behaviour": asdict(Behaviour()),
           "seconds": round(time.time() - started, 1), "results": rows}
    Path(args.out).write_text(json.dumps(out, indent=2) + "\n")


if __name__ == "__main__":
    main()
