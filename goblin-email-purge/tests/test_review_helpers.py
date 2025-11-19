from pathlib import Path
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from review_helpers import review_matches


def test_review_matches_programmatic(tmp_path: Path):
    matches = [
        {"id": "1", "providers": ["tinder"]},
        {"id": "2", "providers": ["tinder", "bumble"]},
        {"id": "3", "providers": ["badoo"]},
    ]
    decisions_file = tmp_path / "decisions.json"
    predecisions = {"tinder": "approve", "badoo": "deny"}
    decisions = review_matches(
        matches, decisions_file, interactive=False, predecisions=predecisions
    )
    assert decisions["tinder"] == "approve"
    assert decisions["badoo"] == "deny"
    assert "bumble" not in decisions
