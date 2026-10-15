FROM ghcr.io/astral-sh/uv:0.13.0@sha256:cdc6093146eb3ff6a40107b38f008b789e050e77ad87865e381d9917da55a168 AS uv

FROM python:3.14-slim@sha256:a2b82f3c48559aa0a8446d9af49826b6e2b2016f4cd2afabfe6013ec53729170

ARG GIT_SHA

LABEL org.opencontainers.image.revision="${GIT_SHA}"

ENV GIT_SHA="${GIT_SHA}" \
    PATH="/app/.venv/bin:${PATH}" \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app

COPY --from=uv /uv /uvx /bin/
COPY pyproject.toml uv.lock ./

RUN uv sync --locked --no-dev --no-install-project

COPY api ./api

RUN useradd --create-home --uid 10001 app \
    && chown -R app:app /app

USER app

EXPOSE 8000
#Updated#
CMD ["python", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
