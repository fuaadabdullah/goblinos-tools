import os, sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from unsubscribe_helpers import parse_list_unsubscribe, attempt_unsubscribe


def test_parse_list_unsubscribe():
    header = "<mailto:foo@example.com>, <https://example.com/unsub>"
    parts = parse_list_unsubscribe(header)
    assert "mailto:foo@example.com" in parts
    assert "https://example.com/unsub" in parts


def test_attempt_unsubscribe_dry_run():
    res = attempt_unsubscribe("https://example.com/unsub", dry_run=True)
    assert res["status"] == "dry_run"


def test_attempt_unsubscribe_http(monkeypatch):
    class MockResponse:
        status_code = 200
        text = "ok"

    def fake_get(url, timeout):
        assert url == "https://example.com/unsub"
        return MockResponse()

    monkeypatch.setattr("unsubscribe_helpers.requests.get", fake_get)
    res = attempt_unsubscribe("https://example.com/unsub", dry_run=False)
    assert res["status"] == "ok"


def test_attempt_unsubscribe_mailto(monkeypatch):
    opened = {}

    def fake_open(url):
        opened["url"] = url
        return True

    monkeypatch.setattr("unsubscribe_helpers.webbrowser.open", fake_open)
    res = attempt_unsubscribe("mailto:foo@example.com", dry_run=False)
    assert res["status"] == "ok"
    assert opened["url"].startswith("mailto:")
