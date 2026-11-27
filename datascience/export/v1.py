"""Version 1: v0's numbers with D66's start policy and a zero test that tightens with the nights (#117).

What changed from v0 (export/v0.py) and why:
- policy.hold_nights = 7: the start is drawn on a week's first night and held to Sunday (D66).
- policy.settle_at_insight, settle_plan_within_min = 15: settle on the side the insight supports, or
  at the plan once the 90% range is inside ±15 minutes (D66; reports/dampening.md).
- policy.settled_explore_share = 0.07: about one settled week in 14 draws again (D66).
- insight.zero_test_spend_after, zero_test_spend_power: past that many usable nights, the zero test's
  miss chance shrinks as (after / nights) ** power, so false insights stay under 5% for as long as
  Dusk is used, not only to night 56 (#117; reports/longrun.md).
Everything else is v0's, tuned in reports/tuning.md.
"""

from __future__ import annotations

from . import v0

VERSION = "sleep-model.v1"
HOLD_NIGHTS = 7
SETTLE_PLAN_WITHIN_MIN = 15.0
SETTLED_EXPLORE_SHARE = 0.07
ZERO_TEST_SPEND_AFTER = 30
ZERO_TEST_SPEND_POWER = 2.0


def artifact(**over) -> dict:
    """v1, or a variant of it for tuning (`sim.longrun`): any policy or insight number by name."""
    a = v0.artifact()
    a["schema"] = 2
    a["version"] = over.pop("version", VERSION)
    a["policy"] = a["policy"] | {
        "hold_nights": HOLD_NIGHTS,
        "settle_at_insight": True,
        "settle_plan_within_min": SETTLE_PLAN_WITHIN_MIN,
        "settled_explore_share": SETTLED_EXPLORE_SHARE,
    }
    a["insight"] = a["insight"] | {
        "zero_test_spend_after": ZERO_TEST_SPEND_AFTER,
        "zero_test_spend_power": ZERO_TEST_SPEND_POWER,
    }
    for key, value in over.items():
        section = "policy" if key in a["policy"] else "insight" if key in a["insight"] else None
        if section is None:
            a[key] = value
        else:
            a[section][key] = value
    return a
