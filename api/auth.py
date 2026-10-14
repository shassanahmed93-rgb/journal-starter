import hmac
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from api.config import Settings, get_settings

bearer_scheme = HTTPBearer(auto_error=False)
SettingsDependency = Annotated[Settings, Depends(get_settings)]
BearerCredentials = Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)]


def _matches(token: str, expected: str) -> bool:
    return hmac.compare_digest(token.encode("utf-8"), expected.encode("utf-8"))


def require_api_access(credentials: BearerCredentials, settings: SettingsDependency) -> None:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    if not (
        _matches(token, settings.api_access_token.get_secret_value())
        or _matches(token, settings.api_admin_token.get_secret_value())
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )


def require_admin_access(credentials: BearerCredentials, settings: SettingsDependency) -> None:
    require_api_access(credentials, settings)
    if credentials is None or not _matches(
        credentials.credentials, settings.api_admin_token.get_secret_value()
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access required",
        )
