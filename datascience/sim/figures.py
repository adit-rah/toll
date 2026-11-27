"""The report's figures, drawn from reports/*.json (and one example person run here).

    uv run python -m sim.figures

Colours are the reference palette's categorical slots in fixed order, one per scenario, the same in
every figure; text stays in text colours.
"""

from __future__ import annotations

import json
import tempfile
from datetime import datetime
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from dusk_model import artifact  # noqa: E402
from dusk_model.artifact import Params  # noqa: E402
from export.versions import SHIPPED  # noqa: E402
from replay.evaluate import replay  # noqa: E402
from replay.health import records as health_records  # noqa: E402
from replay.health import write_export  # noqa: E402

from .records import records  # noqa: E402
from .run import run, world  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
FIGURES = REPORTS / "figures"
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
SLOTS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
COLOR = {
    "same": SLOTS[0], "differ": SLOTS[1], "nonresponders": SLOTS[2], "worse": SLOTS[3],
    "nonlinear": SLOTS[4], "null": SLOTS[5], "differ+fade": SLOTS[6],
}
LABEL = {
    "same": "Everyone the same", "differ": "Differ a lot", "nonresponders": "Some don't respond",
    "worse": "Earlier is worse for some", "nonlinear": "Not linear", "null": "Start does nothing",
    "differ+fade": "Differ, effect fades",
}

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "text.color": INK, "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
    "axes.edgecolor": GRID, "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8,
    "axes.spines.top": False, "axes.spines.right": False, "font.size": 10,
    "axes.titlesize": 12, "axes.titleweight": "semibold", "axes.titlelocation": "left",
    "lines.linewidth": 2, "legend.frameon": False, "legend.fontsize": 9,
})


def save(fig, name: str) -> None:
    FIGURES.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIGURES / f"{name}.png", dpi=200, bbox_inches="tight")
    plt.close(fig)


def all_runs(c: dict) -> dict:
    return {**c["scenarios"], "differ+fade": c["fade"]}


def coverage(c: dict) -> None:
    fig, ax = plt.subplots(figsize=(8, 4.2))
    weeks = np.arange(1, 9)
    ax.axhspan(85, 95, color=GRID, alpha=0.6, lw=0)
    ax.text(8.15, 90, "pass band\n85–95%", va="center", color=INK2, fontsize=9)
    for name, s in all_runs(c).items():
        ax.plot(weeks, np.array(s["coverage_by_week"]) * 100, color=COLOR[name], label=LABEL[name],
                ls="--" if name == "differ+fade" else "-", marker="o", ms=4)
    ax.set_ylim(70, 100)
    ax.set_xlabel("Week")
    ax.set_ylabel("People whose 90% range holds the truth (%)")
    ax.set_title("Ranges are honest: 90% ranges hold the true start effect for 85–95% of people")
    ax.legend(ncol=2, loc="lower left")
    save(fig, "coverage")


def insight_curve(c: dict) -> None:
    fig, ax = plt.subplots(figsize=(8, 4.2))
    nights = np.arange(1, 57)
    for name, s in all_runs(c).items():
        ax.plot(nights, np.array(s["shown_by_night"]) * 100, color=COLOR[name], label=LABEL[name],
                ls="--" if name == "differ+fade" else "-")
    ax.axvline(28, color=INK2, lw=1, ls=":")
    ax.text(28.5, 0.98, "night 28", color=INK2, fontsize=9, transform=ax.get_xaxis_transform(), va="top")
    ax.axhline(5, color=INK2, lw=1, ls=":")
    ax.text(1, 6, "5%: most a null effect may show", color=INK2, fontsize=9)
    ax.set_xlabel("Night")
    ax.set_ylabel("People who have seen an insight (%)")
    ax.set_title("Who gets a start-time insight, and when")
    ax.legend(loc="upper left", bbox_to_anchor=(1.01, 1))
    save(fig, "insights-by-night")


def insight_by_effect(c: dict) -> None:
    rows = c["scenarios"]["differ"]["first_insight_by_effect"]
    labels = [f"{r['effect_low']}–{r['effect_high']}" if r["effect_high"] else f"{r['effect_low']}+" for r in rows]
    x = np.arange(len(rows))
    fig, ax = plt.subplots(figsize=(8, 4.2))
    for i, (key, name, color) in enumerate([("shown_by_28", "by night 28", SLOTS[0]), ("shown_by_56", "by night 56", SLOTS[1])]):
        v = np.array([r[key] for r in rows]) * 100
        bars = ax.bar(x + (i - 0.5) * 0.38, v, width=0.36, color=color, label=name, edgecolor=SURFACE, linewidth=2)
        for b, val in zip(bars, v):
            ax.text(b.get_x() + b.get_width() / 2, val + 1.5, f"{val:.0f}", ha="center", fontsize=8, color=INK2)
    ax.set_xticks(x, labels)
    ax.set_xlabel("Size of the person's true effect (minutes of sleep per 30 minutes of start)")
    ax.set_ylabel("Shown an insight (%)")
    ax.set_ylim(0, 105)
    ax.set_title("Insights reach people with large effects; small ones stay unproven (Differ a lot)")
    ax.legend(loc="upper left")
    save(fig, "insights-by-effect")


def benefit(c: dict) -> None:
    fig, ax = plt.subplots(figsize=(8, 4.2))
    weeks = np.arange(1, 9)
    ax.axhline(0, color=INK2, lw=1)
    ax.axhline(5, color=INK2, lw=1, ls=":")
    ax.text(8, 4.6, "+5 min: the most harm allowed", color=INK2, fontsize=9, ha="right", va="top")
    for name, s in all_runs(c).items():
        ax.plot(weeks, s["thompson_minus_fixed_by_week"], color=COLOR[name], label=LABEL[name],
                ls="--" if name == "differ+fade" else "-", marker="o", ms=4)
    ax.set_xlabel("Week")
    ax.set_ylabel("Sleep onset vs always the plan (min; below 0 is earlier)")
    ax.set_ylim(top=6.5)
    ax.set_title("Choosing the start per person: earlier sleep where people differ, no harm elsewhere")
    ax.legend(loc="upper left", bbox_to_anchor=(1.01, 1))
    save(fig, "benefit-by-week")


def example_person(params: Params) -> None:
    w = world("differ", 200, 2026)
    r = run(w, params, "thompson", 2026)
    # A typical person who does get an insight: large effect, every start allowed, the median first night.
    first = np.where(r.shown.any(1), r.shown.argmax(1), 999)
    pool = np.flatnonzero((first < 999) & (w.people.truth[:, 1] > 15) & w.people.allowed.all(1))
    person = int(pool[np.argsort(first[pool])[len(pool) // 2]])
    nights = np.arange(1, 57)
    fig, (ax, strip) = plt.subplots(2, 1, figsize=(8, 5), height_ratios=[4, 1], sharex=True)
    ax.fill_between(nights, r.low[person], r.high[person], color=SLOTS[0], alpha=0.18, lw=0, label="90% range")
    ax.plot(nights, r.estimate[person], color=SLOTS[0], label="Estimate")
    ax.axhline(r.truth[person, 0], color=INK, lw=1.2, ls="--", label="Truth")
    ax.axhline(0, color=INK2, lw=1)
    first = int(r.shown[person].argmax()) + 1
    ax.axvline(first, color=INK2, lw=1, ls=":")
    ax.text(first + 0.5, 0.97, f"insight shown from night {first}", color=INK2, fontsize=9,
            transform=ax.get_xaxis_transform(), va="top")
    ax.set_ylabel("Minutes sooner asleep\nper 30 min earlier start")
    ax.set_title("One simulated person: the range narrows, and the truth stays inside it")
    ax.legend(loc="lower right")
    for a in (-30, 0, 30):
        m = r.home[person] & (r.offset[person] == a)
        strip.scatter(nights[m], np.full(m.sum(), a), color=INK2, s=18, edgecolor=SURFACE, linewidth=1)
    strip.set_yticks([-30, 0, 30], ["−30", "plan", "+30"])
    strip.set_ylim(-45, 45)
    strip.set_xlabel("Night")
    strip.set_ylabel("Start", rotation=0, labelpad=18)
    save(fig, "example-person")


def parity() -> None:
    p = json.loads((REPORTS / "parity.json").read_text())
    pts = p["points"]
    fig, ax = plt.subplots(figsize=(5.5, 5))
    for field, color, name in [("mean", SLOTS[0], "Predicted onset"), ("sd", SLOTS[1], "Prediction sd"), ("insight", SLOTS[2], "Insight minutes")]:
        xs = [q["python"] for q in pts if q["field"] == field]
        ys = [q["swift"] for q in pts if q["field"] == field]
        ax.scatter(xs, ys, s=10, color=color, label=name, alpha=0.7, lw=0)
    lim = [min(q["python"] for q in pts) - 5, max(q["python"] for q in pts) + 5]
    ax.plot(lim, lim, color=INK2, lw=1)
    worst = max(f["max_abs_diff"] for f in p["fields"].values())
    ax.set_xlabel("Python reference")
    ax.set_ylabel("Swift package")
    ax.set_title("Swift matches Python")
    ax.text(0.03, 0.95, f"{p['values']:,} values over {p['nights']} nights\nlargest difference {worst:.2g}\n"
            f"chosen starts differing: {p['choice_or_generator_mismatches']}", transform=ax.transAxes,
            va="top", fontsize=9, color=INK2)
    ax.legend(loc="lower right")
    save(fig, "parity")


def replay_synthetic(params: Params, tmp: Path) -> dict:
    """Health exports written from simulated people with no Dusk yet, read back and replayed."""
    w = world("null", 200, 99)
    r = run(w, params, "fixed")
    weekly = {"model": [[] for _ in range(8)], "base": [[] for _ in range(8)]}
    beats = []
    for p in range(200):
        nights = records(w, r, p, params.version, "fixed")
        path = tmp / "export.xml"
        write_export(path, nights)
        bed = datetime.fromisoformat(nights[0]["planned_bedtime"]).time()
        wk = datetime.fromisoformat(next(n for n in nights if n["weekend"])["planned_bedtime"]).time()
        rep = replay(health_records(path, bed, wk), params)
        beats.append(rep.get("beats_base_after_3_weeks", False))
        for row in rep["rows"]:
            week = min(row["index"] // 7, 7)
            weekly["model"][week].append(abs(row["y"] - row["model"]))
            weekly["base"][week].append(abs(row["y"] - row["base"]))
    out = {
        "people": 200,
        "share_beating_base_after_3_weeks": float(np.mean(beats)),
        "mae_by_week": {k: [float(np.mean(v)) for v in vs] for k, vs in weekly.items()},
    }
    (REPORTS / "replay-synthetic.json").write_text(json.dumps(out, indent=2) + "\n")
    fig, ax = plt.subplots(figsize=(8, 4))
    weeks = np.arange(1, 9)
    ax.plot(weeks, out["mae_by_week"]["base"], color=SLOTS[1], marker="o", ms=4, label="Base alone")
    ax.plot(weeks, out["mae_by_week"]["model"], color=SLOTS[0], marker="o", ms=4, label="Base + person")
    ax.axvline(3.5, color=INK2, lw=1, ls=":")
    ax.text(3.6, 0.03, "after 3 weeks", color=INK2, fontsize=9, transform=ax.get_xaxis_transform())
    ax.set_xlabel("Week")
    ax.set_ylabel("Mean error predicting tonight's onset (min)")
    ax.set_title(f"Replay of 200 synthetic Health exports: personal model beats the base for "
                 f"{out['share_beating_base_after_3_weeks']:.0%} after 3 weeks")
    ax.legend()
    save(fig, "replay")
    return out


def long_run() -> None:
    """False insights week by week over a year, from reports/longrun-final.json (#117)."""
    path = REPORTS / "longrun-final.json"
    if not path.exists():
        return
    runs = json.loads(path.read_text())["variants"]
    names = {"v0": "v0: nightly", "d66": "D66, fixed zero test", "v1": "v1: zero test tightens"}
    styles = {"null": "-", "null+wander": "--", "null+drift": ":"}
    fig, ax = plt.subplots(figsize=(7, 4))
    for i, (name, label) in enumerate(names.items()):
        for scenario, style in styles.items():
            series = runs.get(name, {}).get(scenario)
            if series is None:
                continue
            shown = np.array(series["ever_shown_by_week"]) * 100
            weeks = np.arange(1, len(shown) + 1)
            tag = "" if scenario == "null" else f" ({scenario.split('+')[1]})"
            ax.plot(weeks, shown, style, color=SLOTS[i], label=label + tag)
    ax.axhline(5, color=INK2, linewidth=1)
    ax.axvline(8, color=GRID, linewidth=1)
    ax.set_xlabel("Week")
    ax.set_ylabel("Ever shown an insight, start does nothing (%)")
    ax.set_title("False insights over a year")
    ax.legend(loc="upper left", ncols=1)
    save(fig, "false-insights-year")


def main() -> None:
    params = Params.from_artifact(artifact.load(ROOT / "artifacts" / f"{SHIPPED.VERSION}.json"))
    c = json.loads((REPORTS / "criteria.json").read_text())
    coverage(c)
    insight_curve(c)
    insight_by_effect(c)
    benefit(c)
    example_person(params)
    if (REPORTS / "parity.json").exists():
        parity()
    long_run()
    with tempfile.TemporaryDirectory() as tmp:
        print(json.dumps(replay_synthetic(params, Path(tmp))["share_beating_base_after_3_weeks"]))
    print("figures in", FIGURES)


if __name__ == "__main__":
    main()
