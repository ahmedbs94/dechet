"""
routers/admin_dashboard.py — GET /admin/dashboard
==================================================
Endpoint unique retournant tous les KPIs en un seul appel.
Cache mémoire 60s pour éviter les recalculs à chaque ouverture d'onglet.
Flutter charge les cartes du dashboard avec ce seul endpoint.

Endpoints exposés :
  GET  /admin/dashboard        → données avec cache 60s (header X-Cache-Age)
  GET  /admin/dashboard/live   → données fraîches (pas de cache, pour pull-to-refresh)
  POST /admin/dashboard/cache/invalidate → invalide manuellement le cache
"""
import time
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from database import get_db
from core.deps import get_admin_user
from services import admin_analytics_service as svc
from schemas.admin_analytics import AdminDashboardResponse

router = APIRouter(prefix="/admin", tags=["admin-dashboard"])

# ── Cache mémoire simple (60 secondes) ───────────────────────────────────────
_CACHE_TTL_SECONDS = 60
_cache: dict = {
    "data": None,
    "expires_at": None,
    "computed_at": None,   # timestamp float pour calculer X-Cache-Age
}


def _get_cached_or_compute(db: Session) -> tuple[AdminDashboardResponse, int]:
    """
    Retourne (résultat, cache_age_seconds).
    cache_age_seconds = 0 si données fraîches, sinon nombre de secondes depuis le calcul.
    """
    now = datetime.utcnow()
    now_ts = time.time()

    if (
        _cache["data"] is not None
        and _cache["expires_at"] is not None
        and now < _cache["expires_at"]
    ):
        age = int(now_ts - _cache["computed_at"])
        return _cache["data"], age

    # Recalcul
    result = svc.get_dashboard_summary(db)
    _cache["data"] = result
    _cache["expires_at"] = now + timedelta(seconds=_CACHE_TTL_SECONDS)
    _cache["computed_at"] = now_ts
    return result, 0


@router.get(
    "/dashboard",
    response_model=AdminDashboardResponse,
    summary="Dashboard admin — KPIs globaux (cache 60s)",
    description=(
        "Retourne tous les indicateurs principaux en un seul appel. "
        "Sécurisé : requiert role=admin. "
        "Résultat mis en cache 60s côté serveur. "
        "Header X-Cache-Age : nombre de secondes depuis le dernier calcul (0 = données fraîches)."
    ),
)
async def admin_dashboard(
    response: Response,
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
) -> AdminDashboardResponse:
    result, cache_age = _get_cached_or_compute(db)
    response.headers["X-Cache-Age"] = str(cache_age)
    response.headers["X-Cache-TTL"] = str(_CACHE_TTL_SECONDS)
    return result


@router.get(
    "/dashboard/live",
    response_model=AdminDashboardResponse,
    summary="Dashboard admin — données instantanées (sans cache)",
    description=(
        "Force le recalcul immédiat des KPIs, ignore le cache. "
        "À utiliser pour le pull-to-refresh manuel depuis Flutter. "
        "Invalide aussi le cache pour que le prochain GET /admin/dashboard serve les nouvelles données."
    ),
)
async def admin_dashboard_live(
    response: Response,
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
) -> AdminDashboardResponse:
    # Recalcul forcé + mise à jour du cache
    result = svc.get_dashboard_summary(db)
    _cache["data"] = result
    _cache["expires_at"] = datetime.utcnow() + timedelta(seconds=_CACHE_TTL_SECONDS)
    _cache["computed_at"] = time.time()
    response.headers["X-Cache-Age"] = "0"
    response.headers["X-Cache-TTL"] = str(_CACHE_TTL_SECONDS)
    return result


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
    _cache["computed_at"] = None
    return {"success": True, "message": "Cache invalidé — prochain appel recalculera les données"}
