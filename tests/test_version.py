from fastapi.testclient import TestClient

from api.main import app


def test_version_returns_configured_full_commit_sha(monkeypatch):
    commit = "a" * 40
    monkeypatch.setenv("GIT_SHA", commit)

    response = TestClient(app).get("/version")

    assert response.status_code == 200
    assert response.json() == {"commit": commit}


def test_version_rejects_missing_commit_sha(monkeypatch):
    monkeypatch.delenv("GIT_SHA", raising=False)

    response = TestClient(app).get("/version")

    assert response.status_code == 503
    assert response.json() == {"detail": "Build commit SHA is not configured"}
