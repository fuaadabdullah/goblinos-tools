import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from unsubscribe_helpers import attempt_unsubscribe


def test_post_fallback(monkeypatch):
    class MockResp:
        def __init__(self, code, text=""):
            self.status_code = code
            self.text = text

    calls = {"get": [], "post": []}

    def fake_get(url, timeout):
        calls["get"].append(url)
        return MockResp(405, "Method Not Allowed")

    def fake_post(url, timeout, data):
        calls["post"].append((url, data))
        return MockResp(200, "OK")

    monkeypatch.setattr("unsubscribe_helpers.requests.get", fake_get)
    monkeypatch.setattr("unsubscribe_helpers.requests.post", fake_post)
    res = attempt_unsubscribe("https://example.com/unsub", dry_run=False)
    assert res["status"] == "ok"
    assert calls["get"] and calls["post"]
