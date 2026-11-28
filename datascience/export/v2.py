"""Version 2: v1 with ranges that stay honest when a person's usual time moves (#154).

What changed from v1 (export/v1.py) and why (reports/longrun.md, section 7):
- schema 3. v1 treated every night's noise as independent, so a week whose usual time moved read as
  an effect of that week's held start (reports/longrun.md, section 5).
- noise_scale_prior_nights = 5: each person's nights can be noisier than noise_sd, or move together
  for days or weeks; the scale is learned from week sums of residuals, starting from this many nights
  at noise_sd, and the zero tests are a t's over the weeks it rests on (`dusk_model.model`).
- intercept_week_sd = 0: the intercept may wander between weeks (a Kalman step), but that cost more
  learning than the scale for the same safety, so v2 leaves it off.
- insight.zero_test_interval = 0.95: with honest ranges, the 98% test was stricter than the 5% mark
  needs, so it is lowered to win back learning.
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
