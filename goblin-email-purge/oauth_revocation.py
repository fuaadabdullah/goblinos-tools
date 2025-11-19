import requests
from typing import Dict


def revoke_google_token(token: str, dry_run: bool = True) -> Dict:
    """Revoke an OAuth token for Google via public revocation endpoint.
    If dry_run True, don't actually send the HTTP request.
    """
    if dry_run:
        return {
            "status": "dry_run",
            "message": "Would POST to https://oauth2.googleapis.com/revoke?token=TOKEN",
        }
    url = "https://oauth2.googleapis.com/revoke"
    try:
        r = requests.post(url, data={"token": token}, timeout=10)
        if r.status_code in (200, 400):
            # 200 = revoked, 400 = token already invalid
            return {"status": "ok", "code": r.status_code, "body": r.text}
        return {"status": "error", "code": r.status_code, "body": r.text}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def revoke_facebook_token(token: str, dry_run: bool = True) -> Dict:
    """Remove user access by deleting /me/permissions - requires a user access token with proper permissions."""
    if dry_run:
        return {
            "status": "dry_run",
            "message": "Would DELETE https://graph.facebook.com/me/permissions?access_token=TOKEN",
        }

    url = f"https://graph.facebook.com/me/permissions?access_token={token}"
    try:
        r = requests.delete(url, timeout=10)
        if r.status_code in (200,):
            return {"status": "ok", "code": r.status_code, "body": r.text}
        else:
            return {"status": "error", "code": r.status_code, "body": r.text}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def revoke_apple_token(token: str, dry_run: bool = True) -> Dict:
    """Apple Sign-In tokens cannot be revoked programmatically.
    Provide manual steps for the user.
    """
    message = (
        "Apple Sign-In does not support programmatic token revocation. "
        "To revoke access: "
        "1. Go to https://appleid.apple.com/ "
        "2. Sign in with your Apple ID. "
        "3. Go to 'Devices' or 'Sign-In & Security' > 'Apps & Websites'. "
        "4. Find the app that used Sign-In and revoke its access."
    )
    if dry_run:
        return {"status": "dry_run", "message": message}
    return {"status": "manual", "message": message}
