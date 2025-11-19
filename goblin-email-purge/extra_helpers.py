from typing import Optional

PROVIDER_DELETION_URLS = {
    "tinder": "https://www.google.com/search?q=delete+account+tinder",
    "bumble": "https://bumble.com/delete-account",
    "hinge": "https://hinge.co/account-deletion",
    "okcupid": "https://www.okcupid.com/app/settings/delete",
    "match": "https://www.match.com/settings/delete",
    "eharmony": "https://www.eharmony.com/account-settings/",
    "plentyoffish": "https://www.pof.com/delete.aspx",
    "badoo": "https://badoo.com/help/2193/",
}


def provider_deletion_url(provider: str) -> Optional[str]:
    if not provider:
        return None
    provider = provider.lower()
    return PROVIDER_DELETION_URLS.get(
        provider, f"https://www.google.com/search?q=delete+account+{provider}"
    )
