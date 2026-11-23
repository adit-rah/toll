"""The dampening report's figure: what each policy costs in sleep and in learning, against how much the
start moves from night to night. Drawn from reports/dampening-sweep.json.

    uv run python -m sim.dampen_figure
"""

from __future__ import annotations

import json

from .figures import INK2, REPORTS, SLOTS, SURFACE, plt, save

FAMILY = [
    ("v0 (±30, every night)", ("v0",)),
    ("Smaller moves", ("grid15", "grid15-prior40", "grid15-width60", "grid20x10", "grid10x5")),
    ("Plan by default", ("k1", "k2", "k3", "k2-uniform", "plan50", "plan70", "k2-settle", "weekly-plan50")),
    ("Walk (step cap)", ("step5", "step10", "step10-tens", "weekly-step10", "settle-insight-step10", "k3-settle-step10")),
    ("Hold a start for days", ("dwell3", "weekly", "fortnight", "weekly15", "weekly15-settle-plan15")),
    ("Settle once sure", ("settle-insight", "settle-conf90", "settle-conf95", "settle-insight-plan15", "weekly-settle",
                          "weekly-settle-plan15", "weekly-settle-plan15-max15", "weekly-settle-plan10", "weekly-conf95",
                          "dwell3-settle", "dwell3-settle-plan15")),
]
CALLOUT = {"v0": "v0", "weekly-settle-plan15": "weekly, settle", "dwell3-settle-plan15": "3 nights, settle",
           "grid15": "±15", "k2": "2 nights a week", "step10": "10 min a night", "settle-conf90": "settle at 90%"}


def main() -> None:
    d = json.loads((REPORTS / "dampening-sweep.json").read_text())["policies"]
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.4))
    panels = [("benefit", "Minutes of sleep onset a night vs the plan", -1), ("big_effect_by_56", "Effects ≥15 min: insight by night 56 (%)", 100)]
    for ax, (key, title, scale) in zip(axes, panels):
        for i, (family, names) in enumerate(FAMILY):
            xs = [d[n]["scenarios"]["differ"]["mean_abs_change"] for n in names if n in d]
            ys = [d[n]["scenarios"]["differ"][key] * scale for n in names if n in d]
            ax.scatter(xs, ys, s=46, color=SLOTS[i], edgecolor=SURFACE, linewidth=1.5, label=family, zorder=3)
        for n, label in CALLOUT.items():
            s = d[n]["scenarios"]["differ"]
            ax.annotate(label, (s["mean_abs_change"], s[key] * scale), xytext=(6, 4), textcoords="offset points",
                        fontsize=8, color=INK2)
        ax.set_title(title)
        ax.set_xlabel("Mean change in the start from the last block night (min)")
        ax.set_xlim(0, 22)
    axes[0].set_ylabel("Earlier sleep (min a night)")
    axes[1].axhline(50, color=INK2, lw=1, ls=":")
    axes[1].text(21.5, 51.5, "proposed mark: 50%", color=INK2, fontsize=8, ha="right")
    axes[0].legend(loc="upper left", bbox_to_anchor=(0, -0.18), ncol=6, fontsize=8)
    fig.suptitle("Differ a lot, 1,000 people, 8 weeks", x=0.01, ha="left", fontsize=9, color=INK2)
    save(fig, "dampening")


if __name__ == "__main__":
    main()
