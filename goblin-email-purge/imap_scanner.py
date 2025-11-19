import imaplib
import email
from email.header import decode_header
from datetime import datetime, timedelta
import os

CANDIDATE_PROVIDERS = [
    "tinder",
    "bumble",
    "hinge",
    "okcupid",
    "match",
    "eharmony",
    "plentyoffish",
    "poF",
    "badoo",
]


def decode_mime_words(s: str) -> str:
    try:
        dh = decode_header(s)
        return "".join(
            [
                str(t[0], t[1] or "utf-8") if isinstance(t[0], bytes) else t[0]
                for t in dh
            ]
        )
    except Exception:
        return s


def _search_since_date_str(days: int):
    since_date = datetime.utcnow() - timedelta(days=days)
    # IMAP uses DD-Mon-YYYY
    return since_date.strftime("%d-%b-%Y")


def scan_inbox_for_matches(cfg: dict):
    imap_cfg = cfg.get("imap", {})
    host = imap_cfg.get("host")
    port = imap_cfg.get("port", 993)
    username = imap_cfg.get("username")
    pw_env = imap_cfg.get("password_env_var")
    password = os.environ.get(pw_env) if pw_env else imap_cfg.get("password")
    mailbox = imap_cfg.get("mailbox", "INBOX")
    days = imap_cfg.get("search_since_days", 365)

    if not host or not username or not password:
        # Minimal check: return empty list if not configured
        return []

    try:
        mail = imaplib.IMAP4_SSL(host, port)
        mail.login(username, password)
    except Exception:
        # Never raise; return empty list for safety
        return []

    try:
        mail.select(mailbox)
        date_str = _search_since_date_str(days)
        status, messages = mail.search(None, f'(SINCE "{date_str}")')
        if status != "OK":
            status, messages = mail.search(None, "ALL")
        ids = messages[0].split()
        results = []
        for msgid in ids:  # scan all messages in the date range
            status, data = mail.fetch(msgid, "(RFC822.HEADER)")
            if status != "OK":
                continue
            raw = data[0][1]
            m = email.message_from_bytes(raw)
            subject = m.get("Subject", "")
            list_unsub = (
                m.get("List-Unsubscribe")
                or m.get("List-unsubscribe")
                or m.get("List-UNSUBSCRIBE")
            )
            from_ = m.get("From", "")
            date = m.get("Date")
            subject_decoded = decode_mime_words(subject) if subject else ""
            txt = (subject_decoded + " " + from_).lower()
            matched = [p for p in CANDIDATE_PROVIDERS if p.lower() in txt]
            if matched or list_unsub:
                results.append(
                    {
                        "id": msgid.decode()
                        if isinstance(msgid, bytes)
                        else str(msgid),
                        "subject": subject_decoded,
                        "from": from_,
                        "date": date,
                        "providers": matched,
                        "list_unsubscribe": list_unsub,
                    }
                )
        mail.logout()
        return results
    except Exception:
        return []
