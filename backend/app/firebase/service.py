"""
app/firebase/service.py — Service Firebase Admin SDK (miroir de services/firebase_service.py)

Ce module est le futur emplacement canonique du service Firebase.
Pour l'instant, il ré-exporte tout depuis services/firebase_service.py
afin de ne pas casser les imports existants.

Phase 2 : Migrer le contenu ici et supprimer services/firebase_service.py.
"""
from services.firebase_service import (  # noqa: F401
    update_user_score,
    get_user_score,
    generate_custom_token,
    calculate_points,
    WASTE_POINTS,
)

__all__ = [
    "update_user_score",
    "get_user_score",
    "generate_custom_token",
    "calculate_points",
    "WASTE_POINTS",
]
