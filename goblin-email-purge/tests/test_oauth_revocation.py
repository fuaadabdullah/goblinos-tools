import os, sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from oauth_revocation import revoke_google_token, revoke_facebook_token


def test_revoke_google_token_dry_run():
    res = revoke_google_token("fake-token", dry_run=True)
    assert res["status"] == "dry_run"


def test_revoke_google_token_http(monkeypatch):
    class MockResp:
        status_code = 200
        text = "ok"

    def fake_post(url, data, timeout):
        assert url == "https://oauth2.googleapis.com/revoke"
        assert data["token"] == "fake"
        return MockResp()

    monkeypatch.setattr("oauth_revocation.requests.post", fake_post)
    res = revoke_google_token("fake", dry_run=False)
    assert res["status"] == "ok"


def test_revoke_facebook_token_dry_run():
    res = revoke_facebook_token("fake-token", dry_run=True)
    assert res["status"] == "dry_run"


def test_revoke_facebook_token_http(monkeypatch):
    class MockResp:
        status_code = 200
        text = "ok"

    def fake_delete(url, timeout):
        assert url.startswith("https://graph.facebook.com/me/permissions")
        return MockResp()

    monkeypatch.setattr("oauth_revocation.requests.delete", fake_delete)
    res = revoke_facebook_token("fake", dry_run=False)
    assert res["status"] == "ok"
