import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from time import perf_counter

from fastapi import FastAPI
from starlette.middleware.base import RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

from api.config import get_settings
from api.logging_config import configure_logging
from api.repositories.postgres_repository import PostgresDB
from api.routers.journal_router import router as journal_router
from api.routers.version_router import router as version_router
from api.telemetry import instrument_app, record_request

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    configure_logging()
    settings = get_settings()
    async with PostgresDB(settings.database_url, require_ssl=settings.database_ssl) as database:
        app.state.database = database
        try:
            logger.info("Journal API is ready")
            yield
        finally:
            logger.info("Journal API is shutting down")
            del app.state.database


app = FastAPI(
    title="Journal API",
    description="A simple journal API for tracking daily work, struggles, and intentions",
    lifespan=lifespan,
)
app.include_router(journal_router)
app.include_router(version_router)
instrument_app(app)


@app.middleware("http")
async def record_http_metrics(
    request: Request,
    call_next: RequestResponseEndpoint,
) -> Response:
    started_at = perf_counter()
    route = getattr(request.scope.get("route"), "path", "unmatched")
    try:
        response = await call_next(request)
    except Exception:
        record_request(500, route, perf_counter() - started_at)
        raise
    route = getattr(request.scope.get("route"), "path", route)
    record_request(response.status_code, route, perf_counter() - started_at)
    return response
