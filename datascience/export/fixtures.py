"""Parity fixtures: what the Swift package must reproduce (model spec, section 6.3).

Each line is one case: an artifact, a seed, the allowed starts (for the whole case, or night by night
in `allowed_nights`), and a sequence of nights. For each night, in this order, the case records the
policy's choice (tonight's hold, D66), the predictions for every start, the result of the update, and
the state and insights after it.
"""

from __future__ import annotations

import copy
from datetime import datetime, timedelta

import numpy as np

from dusk_model.artifact import Params
from dusk_model.night import context_of
from dusk_model.person import PersonModel, SeededRNG
from dusk_model.rng import SplitMix64
from dusk_model.timing import policy_name
from sim.records import records
from sim.run import NIGHTS, run, world

from . import v0, v1


def case(
    name: str,
    a: dict,
    nights: list[dict],
    seed: int,
    allowed: list[int] | None = None,
    allowed_nights: list[list[int]] | None = None,
) -> dict:
    params = Params.from_artifact(a)
    person = PersonModel(params)
    rng = SeededRNG(seed)
    allowed = list(params.actions) if allowed is None else allowed
    steps = []
    hold = None
    for i, record in enumerate(nights):
        context = context_of(record, params)
        tonight = allowed if allowed_nights is None else allowed_nights[i]
        hold = person.choose_start(record["night"], context, rng, tonight, hold)
        predictions = [
            {"offset": a_, "mean": m, "sd": sd}
            for a_ in params.actions
            for m, sd in [person.predict(context, a_)]
        ]
        used, reason = person.update(record)
        steps.append(
            {
                "context": {"weekend": context.weekend, "late": context.late},
                "choice": {
                    "offset": hold["offset"],
                    "prob": hold["prob"],
                    "hold_start": hold["start"],
                    "settled": hold["settled"],
                },
                "predictions": predictions,
                "used": used,
                "skip": reason,
                "state": person.state,
                "insights": person.insights(),
                "rng_state": f"{rng.state:016x}",
            }
        )
    out = {"name": name, "artifact": a, "seed": seed, "allowed": allowed, "nights": nights, "steps": steps}
    if allowed_nights is not None:
        out["allowed_nights"] = allowed_nights
    return out


def simulated_nights(
    scenario: str, seed: int, person: int = 0, fade: bool = False, a: dict | None = None, nights: int = NIGHTS
) -> list[dict]:
    params = Params.from_artifact(a or v1.artifact())
    w = world(scenario, person + 1, seed, fade, nights=nights)
    r = run(w, params, "thompson", seed)
    return records(w, r, person, params.version, policy_name(params), seed)


def edge_nights() -> list[dict]:
    """Each skip reason, the residual clip, a late arrival and a While Using night with no arrival."""
    base = simulated_nights("differ", 7)[:12]
    nights = copy.deepcopy(base)
    home = [n for n in nights if n["block_start"] is not None]
    home[0]["sleep_onset"] = None
    home[1]["tz_changed"] = True
    home[2]["block_start"] = None
    home[3]["action_offset_min"] = 15
    home[4]["sleep_onset"] = home[4]["planned_wake"]  # 8 hours late: onset_far
    home[5]["sleep_onset"] = _shift(home[5]["planned_bedtime"], 200)  # clipped residual
    home[6]["home_arrival"] = _shift(home[6]["planned_bedtime"], -10)
    home[7]["home_arrival"] = None
    return nights


def _shift(iso: str, minutes: float) -> str:
    return (datetime.fromisoformat(iso) + timedelta(minutes=minutes)).isoformat()


def rng_case() -> dict:
    rng = SplitMix64(0x5EED)
    u64 = [f"{int(x):016x}" for x in rng.u64(8)]
    uniform = [float(x) for x in rng.uniform(8)]
    normal = [float(x) for x in rng.normal(8)]
    return {"name": "rng", "seed": 0x5EED, "u64": u64, "uniform": uniform, "normal": normal}


def changing_limits(count: int) -> list[list[int]]:
    """Night by night: every start, then "never earlier" from the third night of week 2, then "never
    later" from the fifth night of week 4, so a held start stops being allowed mid-week."""
    return [[-30, 0, 30] if t < 9 else [0, 30] if t < 25 else [-30, 0] for t in range(count)]


def all_cases() -> list[dict]:
    a = v1.artifact()
    # Small enough numbers that 8 weeks settle at the insight, at the plan, and explore when settled.
    quick = v1.artifact(
        hold_nights=3,
        settle_plan_within_min=20.0,
        settled_explore_share=0.3,
        zero_test_spend_after=10,
        zero_test_spend_power=2.0,
    ) | {"forgetting": 0.97, "noise_sd": 25.0}
    quick["policy"] |= {"min_prob": 0.2, "prob_draws": 200}
    quick["insight"] |= {"interval": 0.8, "zero_test_interval": 0.9, "max_width_min": 40.0, "min_nights": 5}
    quick["prior"] = {"mean": [5.0, 2.0, 0.0, -5.0], "cov_diag_sd": [25.0, 20.0, 15.0, 10.0]}
    five = copy.deepcopy(a) | {"actions": [-30, -15, 0, 15, 30]}
    five["policy"] |= {"min_prob": 0.05, "prob_draws": 500}
    cases = [
        case("differ-8-weeks", a, simulated_nights("differ", 11), seed=1),
        case("worse-8-weeks", a, simulated_nights("worse", 12, person=3), seed=2),
        case("null-8-weeks", a, simulated_nights("null", 13, person=1), seed=3),
        case("edges", a, edge_nights(), seed=4),
        case("never-later", a, simulated_nights("differ", 14, person=2), seed=5, allowed=[-30, 0]),
        case("only-plan", a, simulated_nights("same", 15)[:10], seed=6, allowed=[0]),
        case("quick-settling", quick, simulated_nights("differ", 16, fade=True, nights=112), seed=7),
        case("quick-null", quick, simulated_nights("null", 19, person=2), seed=9),
        case("five-actions", five, simulated_nights("differ", 17)[:21], seed=8),
        case("limits-change", a, simulated_nights("differ", 20)[:35], seed=10, allowed_nights=changing_limits(35)),
        case("16-weeks", a, simulated_nights("differ", 18, nights=112), seed=11),
        case("v0-artifact", v0.artifact(), simulated_nights("differ", 22, a=v0.artifact()), seed=12),
    ]
    return cases


def check_nonempty(cases: list[dict]) -> None:
    """Fixtures must exercise what they claim: skips, insights, every start, and each way a hold ends."""
    steps = [s for c in cases for s in c["steps"]]
    reasons = {s["skip"] for s in steps}
    for reason in ("no_sleep_data", "away", "tz_changed", "no_block", "unknown_action", "onset_far"):
        if reason not in reasons:
            raise AssertionError(f"no fixture skips a night for {reason}")
    if not any(s["insights"] for s in steps):
        raise AssertionError("no fixture shows an insight")
    if not np.isin([-30, 0, 30], [s["choice"]["offset"] for s in steps]).all():
        raise AssertionError("some start is never chosen")
    choices = [s["choice"] for s in steps]
    if not any(c["settled"] and c["offset"] != 0 for c in choices):
        raise AssertionError("no fixture settles at the insight")
    if not any(c["settled"] and c["offset"] == 0 for c in choices):
        raise AssertionError("no fixture settles at the plan")
    if not any(c["settled"] and c["prob"] < 0.5 for c in choices):
        raise AssertionError("no settled person explores")
    pairs = [(a, b) for c in cases for a, b in zip(c["steps"], c["steps"][1:])]
    if not any(a["state"]["shown"] and not b["state"]["shown"] for a, b in pairs):
        raise AssertionError("no fixture withdraws an insight")
    limits = next(c for c in cases if c["name"] == "limits-change")
    starts = [s["choice"]["hold_start"] for s in limits["steps"]]
    if not any(datetime.fromisoformat(s).weekday() != 0 for s in starts):
        raise AssertionError("no hold is redrawn mid-week")
