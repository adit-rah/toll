"""The night log read as the app reads it, and the state rebuilt from it (#140)."""

from dusk_model.artifact import Params
from dusk_model.night import latest, revision
from dusk_model.person import PersonModel, rebuild
from export import rebuild as fixture
from export.v0 import artifact as v0

PARAMS = Params.from_artifact(v0())


def test_lines_without_a_revision_are_revision_one():
    assert revision({"night": "2026-11-10"}) == 1
    assert revision({"night": "2026-11-10", "rev": 3}) == 3


def test_the_highest_revision_wins_and_the_first_of_equals():
    lines = [
        {"night": "2026-11-11", "n": "a"},
        {"night": "2026-11-10", "rev": 1, "n": "b"},
        {"night": "2026-11-10", "rev": 2, "n": "c"},
        {"night": "2026-11-11", "rev": 1, "n": "d"},
        {"night": "2026-11-10", "rev": 2, "n": "e"},
    ]
    assert [r["n"] for r in latest(lines)] == ["c", "a"]


def test_the_fixture_holds_every_shape_and_every_case():
    lines = fixture.lines()
    assert any("bed" not in r for r in lines)
    assert any("bed" in r and "helper" not in r for r in lines)
    assert any("helper" in r and "record" not in r for r in lines)
    assert any(r.get("record") == 2 and r.get("rev") == 1 for r in lines)
    assert any(r.get("rev") == 3 for r in lines)
    assert any(r["dusk"].get("by") == "monitor" for r in lines)


def test_rebuilding_is_replaying_each_night_once_at_its_latest():
    lines = fixture.lines()
    person = PersonModel(PARAMS)
    used = 0
    for record in latest(lines):
        used += person.update(record)[0]
    assert rebuild(PARAMS, lines).state == person.state
    assert used >= 15
    # The correction wins: without it the twice-corrected night teaches something else.
    first_only = [r for r in lines if not (r["night"] == lines[3]["night"] and r.get("rev") == 3)]
    assert rebuild(PARAMS, first_only).state != person.state
