"""
app/auth/service.py — Service JWT / hashing (miroir de auth.py racine)

Ce module est le futur emplacement canonique du service d'authentification.
Pour l'instant, il ré-exporte tout depuis auth.py (racine backend/).

Phase 3 : Migrer le contenu ici et supprimer auth.py racine.
"""
from auth import (  # noqa: F401
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    SECRET_KEY,
    ALGORITHM,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    REFRESH_TOKEN_EXPIRE_DAYS,
    REFRESH_SECRET,
)

__all__ = [
    "verify_password",
    "get_password_hash",
    "create_access_token",
    "create_refresh_token",
    "decode_refresh_token",
    "SECRET_KEY",
    "ALGORITHM",
    "ACCESS_TOKEN_EXPIRE_MINUTES",
    "REFRESH_TOKEN_EXPIRE_DAYS",
    "REFRESH_SECRET",
]
