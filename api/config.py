import re
from functools import lru_cache

from pydantic import Field, HttpUrl, PostgresDsn, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Typed application settings.

    Values are loaded in this order (later sources override earlier ones):
      1. Defaults defined on the fields below.
      2. A ``.env`` file in the current working directory.
      3. Process environment variables.

    Environment variables are matched case-insensitively, so ``DATABASE_URL``
    in ``.env`` populates ``database_url`` on this model.
    """

    database_url: str = Field(
        repr=False,
        description="PostgreSQL connection URL (e.g. postgresql://user:pass@host:5432/db).",
    )
    database_ssl: bool = Field(
        default=False,
        description="Require TLS for PostgreSQL connections.",
    )
    openai_api_key: SecretStr = Field(
        description=(
            "API key for a provider that supports the OpenAI Responses API. Task 4 uses it to "
            "construct an AsyncOpenAI client; during Tasks 1-3 any non-empty "
            "placeholder works."
        ),
    )
    openai_base_url: str = Field(
        description="Responses API-compatible v1 endpoint for the selected provider.",
    )
    openai_model: str = Field(
        description="Provider model ID or deployment name passed to responses.create().",
    )
    api_access_token: SecretStr = Field(
        repr=False,
        description="Bearer token required for journal API access.",
    )
    api_admin_token: SecretStr = Field(
        repr=False,
        description="Distinct bearer token required for destructive journal operations.",
    )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        hide_input_in_errors=True,
    )

    @field_validator("database_url")
    @classmethod
    def validate_database_url(cls, value: str) -> str:
        url = PostgresDsn(value)
        if url.path in (None, "", "/"):
            raise ValueError("Database URL must include a database name")
        return str(url)

    @field_validator("openai_base_url")
    @classmethod
    def validate_provider_url(cls, value: str) -> str:
        return str(HttpUrl(value))

    @field_validator("openai_api_key")
    @classmethod
    def require_api_key(cls, value: SecretStr) -> SecretStr:
        if not value.get_secret_value().strip():
            raise ValueError("API key must not be blank")
        return value

    @field_validator("openai_model")
    @classmethod
    def require_model(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Model name must not be blank")
        return value

    @field_validator("api_access_token", "api_admin_token")
    @classmethod
    def require_nonblank_api_token(cls, value: SecretStr) -> SecretStr:
        if re.fullmatch(r"[A-Za-z0-9_-]{32,256}", value.get_secret_value()) is None:
            raise ValueError("API bearer tokens must be 32-256 URL-safe characters")
        return value

    @model_validator(mode="after")
    def require_distinct_api_tokens(self) -> Settings:
        if self.api_access_token.get_secret_value() == self.api_admin_token.get_secret_value():
            raise ValueError("API access and administrator tokens must differ")
        return self


@lru_cache
def get_settings() -> Settings:
    """Return cached settings for application startup and LLM client construction.

    The lifespan loads settings before opening the shared database pool.
    Database-backed tests override the router's ``get_database`` dependency
    instead; overriding this function as a FastAPI dependency does not change
    startup settings. Restart the API after editing configuration.
    """
    return Settings()  # type: ignore[call-arg]
