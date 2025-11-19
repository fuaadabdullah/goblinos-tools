from typing import Dict, List, Optional
from collections import Counter
from pathlib import Path
from decision_store import load_decisions, save_decisions


def tally_providers(matches: List[Dict]) -> Dict[str, int]:
    providers = []
    for m in matches:
        providers.extend(m.get("providers", []))
    c = Counter(p.lower() for p in providers)
    return dict(c)


def review_matches(
    matches: List[Dict],
    decisions_file: Path,
    interactive: bool = True,
    predecisions: Optional[Dict[str, str]] = None,
) -> Dict:
    """Review matches and return decisions mapping provider -> action (approve|deny|skip).
    If interactive True, prompt user for decisions. Else, use predecisions mapping.
    """
    tally = tally_providers(matches)
    decisions = load_decisions(decisions_file)
    if predecisions:
        # apply programmatic decisions
        for k, v in predecisions.items():
            decisions[k.lower()] = v
        save_decisions(decisions_file, decisions)
        return decisions

    if not interactive:
        return decisions

    # Interactive mode
    print("Summary: providers discovered (counts):")
    for p, c in sorted(tally.items(), key=lambda x: -x[1]):
        print(f" - {p}: {c}")

    print(
        "Decide per-provider: [a]pprove (allow auto actions), [d]eny (block), [s]kip (ignore)"
    )
    for p in sorted(tally.keys()):
        current = decisions.get(p, "skip")
        while True:
            v = input(f"{p} (current={current})> ").strip().lower()
            if not v:
                break
            if v in ("a", "approve"):
                decisions[p] = "approve"
                break
            if v in ("d", "deny"):
                decisions[p] = "deny"
                break
            if v in ("s", "skip"):
                decisions[p] = "skip"
                break
            print("Invalid: enter a/d/s or press Enter to keep")

    save_decisions(decisions_file, decisions)
    return decisions
