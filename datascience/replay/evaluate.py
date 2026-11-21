"""Does the model predict real nights? (model spec, section 6.2)

Nights go through in date order. Each usable night is predicted before the model learns from it, and
the prediction is compared with the base alone and with the night itself.
"""

from __future__ import annotations

import numpy as np

from dusk_model.artifact import Params
from dusk_model.insights import normal_quantile
from dusk_model.model import base
from dusk_model.night import features, phi
from dusk_model.person import PersonModel


def replay(nights: list[dict], params: Params) -> dict:
    person = PersonModel(params)
    rows = []
    for i, night in enumerate(nights):
        f = features(night, params)
        if f.usable:
            m, sd = person.predict(f.context, f.offset)
            f0 = float(base(params, phi(f.offset, f.context)[None, :])[0])
            rows.append({"index": i, "y": f.y, "model": m, "sd": sd, "base": f0})
        person.update(night)
    return summarize(rows, person)


def summarize(rows: list[dict], person: PersonModel, after: int = 21) -> dict:
    """`after` counts calendar nights, as in "better than the base after 3 weeks"."""
    if not rows:
        return {"usable_nights": 0}
    y = np.array([r["y"] for r in rows])
    m = np.array([r["model"] for r in rows])
    f = np.array([r["base"] for r in rows])
    sd = np.array([r["sd"] for r in rows])
    z = normal_quantile(0.95)
    late = np.array([r["index"] >= after for r in rows])
    out = {
        "usable_nights": len(rows),
        "mae_model": float(np.abs(y - m).mean()),
        "mae_base": float(np.abs(y - f).mean()),
        "coverage_90": float((np.abs(y - m) <= z * sd).mean()),
        "rows": rows,
        "final_state": person.state,
        "insights": person.insights(),
    }
    if late.any():
        out[f"mae_model_after_{after}"] = float(np.abs(y - m)[late].mean())
        out[f"mae_base_after_{after}"] = float(np.abs(y - f)[late].mean())
        out["beats_base_after_3_weeks"] = out[f"mae_model_after_{after}"] < out[f"mae_base_after_{after}"]
    return out
