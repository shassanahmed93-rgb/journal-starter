from unittest.mock import AsyncMock

import pytest
from httpx import ASGITransport, AsyncClient

from api.main import app
from api.routers.journal_router import get_entry_service
from api.services.entry_service import EntryService

pytestmark = pytest.mark.no_db

ACCESS_TOKEN = "test-access-" + "a" * 48
ADMIN_TOKEN = "test-admin-" + "b" * 48


async def test_journal_routes_reject_missing_or_invalid_bearer_tokens():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        missing = await client.get("/entries")
        invalid = await client.get(
            "/entries", headers={"Authorization": "Bearer invalid-test-token"}
        )

    assert missing.status_code == 401
    assert missing.headers["www-authenticate"] == "Bearer"
    assert invalid.status_code == 401


async def test_access_token_authorizes_non_destructive_journal_operations(monkeypatch):
    service = AsyncMock(spec=EntryService)
    service.get_all_entries.return_value = []
    monkeypatch.setitem(app.dependency_overrides, get_entry_service, lambda: service)

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
        headers={"Authorization": f"Bearer {ACCESS_TOKEN}"},
    ) as client:
        response = await client.get("/entries")

    assert response.status_code == 200
    assert response.json() == {"entries": [], "count": 0}
    service.get_all_entries.assert_awaited_once()


async def test_access_token_cannot_delete_entries(monkeypatch):
    service = AsyncMock(spec=EntryService)
    monkeypatch.setitem(app.dependency_overrides, get_entry_service, lambda: service)

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
        headers={"Authorization": f"Bearer {ACCESS_TOKEN}"},
    ) as client:
        response = await client.delete("/entries")

    assert response.status_code == 403
    service.delete_all_entries.assert_not_awaited()


async def test_admin_token_authorizes_delete_operation(monkeypatch):
    service = AsyncMock(spec=EntryService)
    monkeypatch.setitem(app.dependency_overrides, get_entry_service, lambda: service)

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
        headers={"Authorization": f"Bearer {ADMIN_TOKEN}"},
    ) as client:
        response = await client.delete("/entries")

    assert response.status_code == 200
    assert response.json() == {"detail": "All entries deleted"}
    service.delete_all_entries.assert_awaited_once()
