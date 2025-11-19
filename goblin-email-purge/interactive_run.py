#!/usr/bin/env python3
from pathlib import Path
import os
import sys
import builtins
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))

from cli import audit


def run_interactive_simulation():
    # Create a temporary config file
    cfg_path = Path("config.example.yaml")
    # Ensure env vars for tokens that will be used in revocation are present
    os.environ["GMAIL_ACCESS_TOKEN"] = "fake-google-token"
    os.environ["FB_ACCESS_TOKEN"] = "fake-fb-token"

    # Monkeypatch scan_inbox_for_matches to return a test message
    import cli as cli_module

    def fake_scan(cfg):
        return [
            {
                "id": "1",
                "subject": "Welcome to Tinder",
                "from": "no-reply@tinder.com",
                "providers": ["tinder", "google", "facebook"],
                "list_unsubscribe": "<mailto:unsubscribe@tinder.com>, <https://example.com/unsub>",
            }
        ]

    cli_module.scan_inbox_for_matches = fake_scan

    # Monkeypatch unsubscribe and revoke functions to log calls
    import unsubscribe_helpers as unsub
    import oauth_revocation as rev

    unsub_calls = []
    revoke_calls = []

    def fake_unsubscribe(target, dry_run=True):
        unsub_calls.append((target, dry_run))
        return {"status": "ok", "target": target, "dry_run": dry_run}

    def fake_revoke_google(token, dry_run=True):
        revoke_calls.append(("google", token, dry_run))
        return {"status": "ok", "token": token, "dry_run": dry_run}

    def fake_revoke_fb(token, dry_run=True):
        revoke_calls.append(("facebook", token, dry_run))
        return {"status": "ok", "token": token, "dry_run": dry_run}

    unsub.attempt_unsubscribe = fake_unsubscribe
    cli_module.attempt_unsubscribe = fake_unsubscribe
    rev.revoke_google_token = fake_revoke_google
    rev.revoke_facebook_token = fake_revoke_fb
    # override functions also in cli module to ensure cli's imported references point to our fakes
    cli_module.revoke_google_token = fake_revoke_google
    cli_module.revoke_facebook_token = fake_revoke_fb

    # Monkeypatch webbrowser.open
    import webbrowser

    opened = []

    def fake_open(url):
        opened.append(url)
        return True

    webbrowser.open = fake_open

    # Simulation of interactive inputs: open(1), unsubscribe(1) with confirmations, revoke google & facebook, quit
    seq = iter(["o 1", "u 1", "y", "y", "r google", "y", "r facebook", "y", "q"])
    original_input = builtins.input

    def fake_input(prompt=""):
        try:
            val = next(seq)
            print(prompt + val)
            time.sleep(0.1)
            return val
        except StopIteration:
            return "q"

    builtins.input = fake_input
    try:
        audit(config=cfg_path, interactive=True)
    finally:
        builtins.input = original_input

    print("\nInteractive simulation results:")
    print("Opened URLs:", opened)
    print("Unsubscribe calls:", unsub_calls)
    print("Revoke calls:", revoke_calls)


if __name__ == "__main__":
    run_interactive_simulation()
