import re
import requests
import webbrowser
from typing import List


def parse_list_unsubscribe(header: str) -> List[str]:
    # RFC allows comma-separated addresses/URLS, possibly surrounded by <>
    if not header:
        return []
    parts = re.split(r",\s*", header)
    cleaned = []
    for p in parts:
        p = p.strip()
        if p.startswith("<") and p.endswith(">"):
            p = p[1:-1].strip()
        cleaned.append(p)
    return cleaned


def attempt_unsubscribe(target: str, dry_run: bool = True) -> dict:
    """Try to unsubscribe using the List-Unsubscribe link.
    - mailto: -> opens a mailto: link in default mail client (unless dry-run)
    - http/https -> performs a GET and returns response status
    - If dry_run True, do not actually make network calls, just return planned action
    """
    if not target:
        return {"status": "error", "message": "empty target"}
    target = target.strip()
    if dry_run:
        return {"status": "dry_run", "target": target}
    if target.lower().startswith("mailto:"):
        webbrowser.open(target)
        return {"status": "ok", "target": target, "method": "mailto"}
    if target.lower().startswith("http"):
        try:
            r = requests.get(target, timeout=10)
            if r.status_code < 400:
                return {"status": "ok", "code": r.status_code, "text": r.text[:200]}
            # Some endpoints return 405/403 - attempt POST fallback
            if r.status_code in (405, 403):
                try:
                    p = requests.post(target, timeout=10, data={"unsubscribe": "1"})
                    return {
                        "status": "ok" if p.status_code < 400 else "error",
                        "code": p.status_code,
                        "text": p.text[:200],
                    }
                except Exception as e:
                    return {
                        "status": "error",
                        "message": f"POST fallback failed: {str(e)}",
                    }
            return {"status": "error", "code": r.status_code, "text": r.text[:200]}
        except Exception as e:
            return {"status": "error", "message": str(e)}
    return {"status": "error", "message": "Unsupported protocol"}
