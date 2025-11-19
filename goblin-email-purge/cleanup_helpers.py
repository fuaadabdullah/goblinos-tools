from typing import List


def generate_cleanup_plan(matches: List[dict], cfg: dict) -> List[dict]:
    """Return a cleanup plan listing manual steps and safe guidance for each match."""
    plans = []
    seen_providers = set()
    for m in matches:
        for p in m.get("providers", []):
            if p in seen_providers:
                continue
            seen_providers.add(p)
            plans.append(
                {
                    "provider": p,
                    "manual_steps": [
                        f"Log into {p} via web UI and search for account by email or phone shown in messages",
                        "Use account deletion flow or request account deletion; if you can’t find an automated flow, contact support",
                        "Remove connected apps and sessions, and ask for data deletion if needed",
                    ],
                    "notes": "This is a manual operation in most cases; check the report for exact messages and timestamps.",
                }
            )

    # Add some local macOS cleanup hints
    plans.append(
        {
            "provider": "local_device_cleanup",
            "manual_steps": [
                "Sign out from accounts in System Preferences -> Internet Accounts",
                "Search for saved passwords in Safari or iCloud keychain and remove entries for matching sites",
                "Search Downloads and Documents for exported data and delete them",
            ],
            "notes": "Operations are destructive; perform manually and with backups.",
        }
    )

    return plans
