# core/deps.py — Shared dependencies (auth guards, helpers)
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from database import get_db
import db_models as db_models

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


def _utc_iso(dt) -> str | None:
    """Return ISO string with +00:00 suffix so clients know it's UTC."""
    if dt is None:
        return None
    return dt.isoformat() + "+00:00"


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> db_models.User:
    from jose import jwt, JWTError
    from app.auth.service import SECRET_KEY, ALGORITHM

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("mfa_pending") is True:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="MFA verification pending",
                headers={"WWW-Authenticate": "Bearer"},
            )
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(db_models.User).filter(db_models.User.email == email).first()
    if user is None:
        raise credentials_exception
    return user


async def get_admin_user(
    current_user: db_models.User = Depends(get_current_user),
) -> db_models.User:
    if current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seuls les administrateurs peuvent effectuer cette action",
        )
    return current_user


async def get_superadmin_user(
    current_user: db_models.User = Depends(get_current_user),
) -> db_models.User:
    if current_user.role != "superadmin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seuls les super-administrateurs peuvent effectuer cette action",
        )
    return current_user

