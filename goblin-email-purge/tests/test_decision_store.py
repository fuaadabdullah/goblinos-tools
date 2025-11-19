from pathlib import Path
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from decision_store import load_decisions, save_decisions


def test_save_and_load_decisions(tmp_path: Path):
    file = tmp_path / "decisions.json"
    decisions = {"tinder": "approve", "bumble": "deny"}
    save_decisions(file, decisions)
    loaded = load_decisions(file)
    assert loaded == decisions
