from pathlib import Path
import argparse

# YAML support is optional. We attempt to import it when reading the config.
import os
from rich.console import Console

# rich.table not used directly yet - keep for future reporting tables
from imap_scanner import scan_inbox_for_matches
from oauth_revocation import (
    revoke_google_token,
    revoke_facebook_token,
    revoke_apple_token,
)
from report_generator import ReportGenerator
from cleanup_helpers import generate_cleanup_plan
from datetime import datetime

console = Console()


def read_config(path: Path):
    if not path.exists():
        raise ValueError(f"Config file not found: {path}")
    try:
        import yaml

        with path.open() as f:
            cfg = yaml.safe_load(f)
        return cfg
    except Exception:
        # Fallback minimal parser: parse simple key: value pairs into a nested dict
        cfg = {}
        with path.open() as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if ":" not in line:
                    continue
                key, val = line.split(":", 1)
                key = key.strip()
                val = val.strip()
                # Very small parser: split top-level keys
                if key in ("imap", "providers", "options", "output"):
                    # Not implementing full nested parsing — return empty for now
                    cfg = cfg or {}
                    continue
                cfg[key] = val
        return cfg


def audit(
    config: Path = Path("config.yaml"),
    force: bool = False,
    interactive: bool = False,
    auto_unsubscribe: bool = False,
    review: bool = False,
    decisions_file: Path = Path("decisions.json"),
    apply_approved: bool = False,
):
    ## duplicate audit def removed
    """Scan inbox and generate a cleanup report"""
    cfg = read_config(config)
    # Merge options
    if "options" not in cfg:
        cfg["options"] = {}
    cfg["options"].setdefault("dry_run", True)

    cfg["options"]["force"] = force

    reports_dir = Path(cfg.get("output", {}).get("reports_dir", "./reports"))
    reports_dir.mkdir(parents=True, exist_ok=True)

    console.print("[bold green]Starting Goblin Email Purge audit[/bold green]")

    matches = scan_inbox_for_matches(cfg)
    console.print(f"[blue]Found {len(matches)} candidate messages")

    # Candidate providers discovered by scanning
    providers = []
    # boolean whether to perform dry_run operations
    do_dry_run = cfg["options"].get("dry_run", True) and not force
    for m in matches:
        providers.extend(m.get("providers", []))
    providers = list(set(providers))

    console.print(f"[magenta]Discovered providers: {providers}")

    attempts = []

    # Revoke tokens if requested (only for configured providers)
    if cfg.get("providers", {}).get("google"):
        token_env = os.environ.get(
            cfg["providers"]["google"].get("revoke_access_token_env", "")
        )
        if token_env:
            console.print(
                f"[yellow]Found Google token in env; attempting revocation... (dry-run: {cfg['options']['dry_run']})"
            )
            res = revoke_google_token(
                token_env, dry_run=cfg["options"]["dry_run"] and not force
            )
            attempts.append({"provider": "google", "result": res})

    if cfg.get("providers", {}).get("facebook"):
        fb_env = os.environ.get(
            cfg["providers"]["facebook"].get("user_access_token_env", "")
        )
        if fb_env:
            console.print(
                f"[yellow]Found Facebook token in env; attempting revocation... (dry-run: {cfg['options']['dry_run']})"
            )
            res = revoke_facebook_token(
                fb_env, dry_run=cfg["options"]["dry_run"] and not force
            )
            attempts.append({"provider": "facebook", "result": res})

    if cfg.get("providers", {}).get("apple"):
        apple_env = os.environ.get(
            cfg["providers"]["apple"].get("access_token_env", "")
        )
        if apple_env:
            console.print(
                f"[yellow]Found Apple token in env; attempting revocation... (dry-run: {cfg['options']['dry_run']})"
            )
            res = revoke_apple_token(
                apple_env, dry_run=cfg["options"]["dry_run"] and not force
            )
            attempts.append({"provider": "apple", "result": res})

    cleanup_plan = generate_cleanup_plan(matches, cfg)

    report = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "matches": matches,
        "attempts": attempts,
        "cleanup_plan": cleanup_plan,
    }

    rg = ReportGenerator(reports_dir)
    fpath = rg.write_report(report)
    console.print(f"[green]Report written to {fpath}")
    # option: review candidates and persist decisions
    if review and matches:
        from review_helpers import review_matches

        decisions = review_matches(
            matches, Path(decisions_file), interactive=interactive
        )
        console.print(f"Decisions written to {decisions_file}")

    # apply approved actions based on decisions file
    if apply_approved:
        from decision_store import load_decisions

        decisions = load_decisions(Path(decisions_file))
        # use decisions to apply actions for approved providers
        for m in matches:
            providers = [p.lower() for p in m.get("providers", [])]
            approved = any(decisions.get(p) == "approve" for p in providers)
            if not approved:
                continue
            # perform actions for approved cases
            # Unsubscribe
            if m.get("list_unsubscribe"):
                from unsubscribe_helpers import (
                    parse_list_unsubscribe,
                    attempt_unsubscribe,
                )

                raw = m.get("list_unsubscribe")
                targets = parse_list_unsubscribe(raw) if isinstance(raw, str) else raw
                for t in targets:
                    console.print(f"Applying unsubscribe to {t} (dry_run={do_dry_run})")
                    res = attempt_unsubscribe(t, dry_run=do_dry_run)
                    attempts.append(
                        {"action": "unsubscribe", "target": t, "result": res}
                    )
            # provider-based revoke
            for p in providers:
                if p == "google" and cfg.get("providers", {}).get("google"):
                    token = os.environ.get(
                        cfg.get("providers", {})
                        .get("google", {})
                        .get("revoke_access_token_env", "")
                    )
                    if token:
                        res = revoke_google_token(token, dry_run=do_dry_run)
                        attempts.append(
                            {"action": "revoke", "provider": "google", "result": res}
                        )
                if p == "facebook" and cfg.get("providers", {}).get("facebook"):
                    token = os.environ.get(
                        cfg.get("providers", {})
                        .get("facebook", {})
                        .get("user_access_token_env", "")
                    )
                    if token:
                        res = revoke_facebook_token(token, dry_run=do_dry_run)
                        attempts.append(
                            {"action": "revoke", "provider": "facebook", "result": res}
                        )
                if p == "apple" and cfg.get("providers", {}).get("apple"):
                    token = os.environ.get(
                        cfg.get("providers", {})
                        .get("apple", {})
                        .get("access_token_env", "")
                    )
                    if token:
                        res = revoke_apple_token(token, dry_run=do_dry_run)
                        attempts.append(
                            {"action": "revoke", "provider": "apple", "result": res}
                        )
    # Interactive mode: ask about revocations/unsubscribes and open deletion pages
    if auto_unsubscribe:
        from unsubscribe_helpers import parse_list_unsubscribe, attempt_unsubscribe

        console.print(
            "[bold]Auto-unsubscribe mode enabled; attempting to unsubscribe where List-Unsubscribe present[/bold]"
        )
        for m in matches:
            raw = m.get("list_unsubscribe")
            if not raw:
                continue
            targets = parse_list_unsubscribe(raw)
            for t in targets:
                console.print(f"Attempting unsubscribe for {m.get('subject')} via {t}")
                res = attempt_unsubscribe(
                    t, dry_run=cfg["options"].get("dry_run", True) and not force
                )
                attempts.append({"action": "unsubscribe", "target": t, "result": res})

    if interactive and matches:
        import webbrowser
        from unsubscribe_helpers import parse_list_unsubscribe, attempt_unsubscribe

        for idx, m in enumerate(matches, start=1):
            console.print(
                f"{idx}) {m.get('subject')} — {m.get('from')} — providers: {m.get('providers')}"
            )
            if m.get("list_unsubscribe"):
                console.print(f"   List-Unsubscribe: {m.get('list_unsubscribe')}")

        # Interactive prompt loop
        while True:
            choice = input("[o]pen, [u]nsubscribe, [r]evoke, [q]uit > ").strip().lower()
            if not choice or choice.startswith("q"):
                break
            if choice.startswith("o"):
                # open deletion page for provider for selected index
                parts = choice.split()
                if len(parts) < 2:
                    console.print("Open: usage 'o <index> <provider>'")
                    continue
                idx = int(parts[1])
                if idx < 1 or idx > len(matches):
                    console.print("Invalid index")
                    continue
                # provider optional
                provider = (
                    parts[2]
                    if len(parts) > 2
                    else (matches[idx - 1].get("providers") or [None])[0]
                )
                deletion_url = None
                from extra_helpers import provider_deletion_url

                if provider:
                    deletion_url = provider_deletion_url(provider)
                if deletion_url:
                    console.print(f"Opening {deletion_url}")
                    webbrowser.open(deletion_url)
                else:
                    console.print(f"No deletion URL for provider: {provider}")
            elif choice.startswith("u"):
                parts = choice.split()
                if len(parts) < 2:
                    console.print("Unsubscribe: usage 'u <index>'")
                    continue
                idx = int(parts[1])
                if idx < 1 or idx > len(matches):
                    console.print("Invalid index")
                    continue
                m = matches[idx - 1]
                raw = m.get("list_unsubscribe")
                if not raw:
                    console.print("No List-Unsubscribe header for this message")
                    continue
                parts = parse_list_unsubscribe(raw)
                for p in parts:
                    console.print(f"Unsubscribe target: {p}")
                    confirm = (
                        input(f"Proceed to unsubscribe via {p}? [y/N]: ")
                        .strip()
                        .lower()
                    )
                    if confirm == "y":
                        res = attempt_unsubscribe(
                            p, dry_run=cfg["options"].get("dry_run", True) and not force
                        )
                        console.print(f"Result: {res}")
            elif choice.startswith("r"):
                parts = choice.split()
                if len(parts) < 2:
                    console.print("Revoke: usage 'r <provider>' (eg r google)")
                    continue
                provider = parts[1]
                if provider == "google":
                    token = os.environ.get(
                        cfg.get("providers", {})
                        .get("google", {})
                        .get("revoke_access_token_env", "")
                    )
                    if token:
                        confirm = (
                            input("Confirm revoke google token? [y/N]: ")
                            .strip()
                            .lower()
                        )
                        if confirm == "y":
                            res = revoke_google_token(
                                token,
                                dry_run=cfg["options"].get("dry_run", True)
                                and not force,
                            )
                            console.print(res)
                elif provider == "facebook":
                    token = os.environ.get(
                        cfg.get("providers", {})
                        .get("facebook", {})
                        .get("user_access_token_env", "")
                    )
                    if token:
                        confirm = (
                            input("Confirm revoke facebook token? [y/N]: ")
                            .strip()
                            .lower()
                        )
                        if confirm == "y":
                            res = revoke_facebook_token(
                                token,
                                dry_run=cfg["options"].get("dry_run", True)
                                and not force,
                            )
                            console.print(res)
                elif provider == "apple":
                    token = os.environ.get(
                        cfg.get("providers", {})
                        .get("apple", {})
                        .get("access_token_env", "")
                    )
                    if token:
                        confirm = (
                            input("Confirm revoke apple token? [y/N]: ").strip().lower()
                        )
                        if confirm == "y":
                            res = revoke_apple_token(
                                token,
                                dry_run=cfg["options"].get("dry_run", True)
                                and not force,
                            )
                            console.print(res)
                else:
                    console.print("Provider not supported for programmatic revocation")


def main():
    parser = argparse.ArgumentParser(description="Goblin Email Purge CLI")
    parser.add_argument(
        "action",
        nargs="?",
        choices=["audit"],
        default="audit",
        help="The action to run",
    )
    parser.add_argument("--config", default="config.yaml", help="Path to config file")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force token revocation (overrides dry-run)",
    )
    parser.add_argument(
        "--interactive", action="store_true", help="Start interactive mode"
    )
    parser.add_argument(
        "--auto-unsubscribe",
        action="store_true",
        help="Attempt automatic unsubscribes using List-Unsubscribe headers",
    )
    parser.add_argument(
        "--review",
        action="store_true",
        help="Enter review mode and persist decision mapping for providers",
    )
    parser.add_argument(
        "--decisions-file",
        default="decisions.json",
        help="Path to decisions.json file",
    )
    parser.add_argument(
        "--apply-approved",
        action="store_true",
        help="Apply approved actions from decisions file (auto-unsubscribe/revoke)",
    )
    args = parser.parse_args()
    if args.action == "audit":
        audit(
            Path(args.config),
            force=args.force,
            interactive=args.interactive,
            auto_unsubscribe=args.auto_unsubscribe,
            review=args.review,
            decisions_file=Path(args.decisions_file),
            apply_approved=args.apply_approved,
        )


if __name__ == "__main__":
    main()
