"""Version 2: v1 with a usual time that can move from week to week, and a noise scale per person (#154).

What changed from v1 (export/v1.py) and why:
- schema 3.
- intercept_week_sd: on a person's first usable night of a calendar week, the intercept's variance
  grows by this squared for each week since their last usable night. v1 treated every night's noise
  as independent, so a week whose usual time moved read as an effect of that week's held start
  (reports/longrun.md, section 5).
- noise_scale_prior_nights: each person's nights can be noisier or calmer than noise_sd; the scale is
  learned from the residuals, starting from this many nights at noise_sd (`dusk_model.model`).
- insight.zero_test_interval: with ranges that are honest about a moving usual time, the 98% test was
  stricter than the 5% mark needs, so it is retuned to win back learning (reports/longrun.md, section 7).
Everything else is v1's.
"""

from __future__ import annotations

from . import v1

VERSION = "sleep-model.v2"
INTERCEPT_WEEK_SD = 0.0
NOISE_SCALE_PRIOR_NIGHTS = 5.0
ZERO_TEST_INTERVAL = 0.95


def artifact(**over) -> dict:
    """v2, or a variant of it for tuning: any number by name, as `v1.artifact` takes them."""
    a = v1.artifact(
        version=over.pop("version", VERSION),
        intercept_week_sd=INTERCEPT_WEEK_SD,
        noise_scale_prior_nights=NOISE_SCALE_PRIOR_NIGHTS,
        zero_test_interval=ZERO_TEST_INTERVAL,
    )
    a["schema"] = 3
    for key, value in over.items():
        section = "policy" if key in a["policy"] else "insight" if key in a["insight"] else None
        if section is None:
            a[key] = value
        else:
            a[section][key] = value
    return a
