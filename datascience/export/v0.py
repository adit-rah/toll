"""Version 0: a hand-set base with an honest prior. Nothing here is fitted (model spec, section 4).

Where each number comes from:
- theta[0] = 15: minutes from planned bedtime to sleep. Young adults spent 39 minutes on average
  between getting into bed and trying to sleep (Exelmans & Van den Bulck 2017); with the phone blocked
  we expect most of that gap gone and a typical 10 to 20 minute sleep latency left.
- theta[1] = 0: the effect of the block's start is unknown, so the base claims none and the prior
  is wide (sd 20 per 30 minutes).
- theta[2] = 30: weekend drift. Social jetlag averages about an hour of mid-sleep shift (Roenneberg
  2012); about half of it shows at sleep onset.
- theta[3] = 20: a late arrival home pushes sleep back; a guess, with a wide prior.
- noise_sd 30, prior sds 20, forgetting 0.99 (a night's weight halves in about 10 weeks), floor 0.10,
  clip 90 and the 98% zero test were tuned in the simulator (reports/tuning.md).
"""

from __future__ import annotations

from dusk_model.artifact import FEATURES, SCHEMA

VERSION = "sleep-model.v0"


def artifact() -> dict:
    return {
        "schema": SCHEMA,
        "version": VERSION,
        "features": FEATURES,
        "base": {"theta": [15.0, 0.0, 30.0, 20.0]},
        "prior": {"mean": [0.0, 0.0, 0.0, 0.0], "cov_diag_sd": [20.0, 20.0, 20.0, 20.0]},
        "noise_sd": 30.0,
        "forgetting": 0.99,
        "actions": [-30, 0, 30],
        "policy": {"min_prob": 0.1, "prob_draws": 1000},
        "context": {"late_home_within_min": 60.0},
        "usable_night": {"max_onset_from_plan_min": 240.0, "residual_clip_min": 90.0},
        "insight": {"interval": 0.9, "zero_test_interval": 0.98, "max_width_min": 30.0, "min_nights": 14},
    }
