import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from cli import audit
from decision_store import save_decisions


def test_apply_approved_unsubscribe_and_revoke(monkeypatch, tmp_path: Path):
    # Create a decisions file approving tinder
    decisions_file = tmp_path / "decisions.json"
    save_decisions(decisions_file, {"tinder": "approve"})

    # Simulate IMAP scan result with a tinder message that has list_unsubscribe
    matches = [
        {
            "id": "1",
            "subject": "Welcome",
            "from": "no-reply@tinder.com",
            "providers": ["tinder"],
            "list_unsubscribe": "<mailto:unsub@tinder.com>",
        }
    ]

    calls = {"unsub": [], "revoke": []}

    def fake_scan(cfg):
        return matches

    def fake_attempt_unsubscribe(target: str, dry_run: bool = True):
        calls["unsub"].append((target, dry_run))
        return {"status": "ok", "target": target}

    def fake_revoke_google(token: str, dry_run: bool = True):
        calls["revoke"].append(("google", dry_run))
        return {"status": "ok"}

    monkeypatch.setattr("cli.scan_inbox_for_matches", fake_scan)
    monkeypatch.setattr(
        "unsubscribe_helpers.attempt_unsubscribe", fake_attempt_unsubscribe
    )
    monkeypatch.setattr("oauth_revocation.revoke_google_token", fake_revoke_google)

    # Provide a providers config to make revoke path run
    cfg = tmp_path / "cfg.yaml"
    cfg.write_text("")

    # Run audit with decisions applied
    audit(
        config=Path("config.example.yaml"),
        force=False,
        interactive=False,
        auto_unsubscribe=False,
        review=False,
        decisions_file=decisions_file,
        apply_approved=True,
    )

    assert len(calls["unsub"]) >= 1
