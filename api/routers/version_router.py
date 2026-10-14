import os
import re

from fastapi import APIRouter, HTTPException

from api.telemetry import tracer

router = APIRouter()


@router.get("/version")
async def get_version() -> dict[str, str]:
    """Return the full commit SHA supplied when the application image was built."""
    commit = os.getenv("GIT_SHA", "")
    with tracer.start_as_current_span("journal.version.lookup") as span:
        configured = re.fullmatch(r"[0-9a-f]{40}", commit) is not None
        span.set_attribute("journal.version.configured", configured)
        if not configured:
            raise HTTPException(status_code=503, detail="Build commit SHA is not configured")
        return {"commit": commit}
