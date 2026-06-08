"""
routers/admin_dashboard.py — GET /admin/dashboard
==================================================
Endpoint unique retournant tous les KPIs en un seul appel.
Cache mémoire 60s pour éviter les recalculs à chaque ouverture d'onglet.
Flutter charge les cartes du dashboard avec ce seul endpoint.
"""
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from core.deps import get_admin_user
from services import admin_analytics_service as svc
from schemas.admin_analytics import AdminDashboardResponse

router = APIRouter(prefix="/admin", tags=["admin-dashboard"])

# ── Cache mémoire simple (60 secondes) ───────────────────────────────────────
_CACHE_TTL_SECONDS = 60
_cache: dict = {"data": None, "expires_at": None}


def _get_cached_or_compute(db: Session) -> AdminDashboardResponse:
    """Retourne le résultat mis en cache ou recalcule si expiré."""
    now = datetime.utcnow()
    if _cache["data"] is not None and _cache["expires_at"] is not None:
        if now < _cache["expires_at"]:
            return _cache["data"]
    # Recalcul
    result = svc.get_dashboard_summary(db)
    _cache["data"] = result
    _cache["expires_at"] = now + timedelta(seconds=_CACHE_TTL_SECONDS)
    return result


@router.get(
    "/dashboard",
    response_model=AdminDashboardResponse,
    summary="Dashboard admin — KPIs globaux (cache 60s)",
    description=(
        "Retourne tous les indicateurs principaux en un seul appel. "
        "Sécurisé : requiert role=admin. "
        "Résultat mis en cache 60s côté serveur. "
        "Flutter doit appeler cet endpoint au chargement de l'écran admin."
    ),
)
async def admin_dashboard(
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
) -> AdminDashboardResponse:
    return _get_cached_or_compute(db)


@router.post(
    "/dashboard/cache/invalidate",
    summary="Invalide manuellement le cache du dashboard",
    description="Force le recalcul au prochain appel GET /admin/dashboard. Requiert role=admin.",
)
async def invalidate_dashboard_cache(
    _admin=Depends(get_admin_user),
):
    _cache["data"] = None
    _cache["expires_at"] = None
    return {"success": True, "message": "Cache invalidé — prochain appel recalculera les données"}
