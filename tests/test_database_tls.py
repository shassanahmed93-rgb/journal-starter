from unittest.mock import AsyncMock

import asyncpg
import pytest

from api.repositories.postgres_repository import PostgresDB


@pytest.mark.no_db
async def test_database_ssl_requires_tls(monkeypatch):
    create_pool = AsyncMock()
    monkeypatch.setattr(asyncpg, "create_pool", create_pool)

    database = PostgresDB("postgresql://db.example.invalid/journal", require_ssl=True)
    await database.__aenter__()

    create_pool.assert_awaited_once_with(
        "postgresql://db.example.invalid/journal",
        ssl="require",
    )
