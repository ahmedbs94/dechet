# routers/analytics.py — Tableau de bord analytique Power BI style
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, case
from datetime import datetime, timedelta
from collections import defaultdict
from typing import Optional

import db_models as db_models
from database import get_db
from core.deps import get_admin_user
from services import admin_analytics_service as svc
from schemas.admin_analytics import (
    ScanStatsResponse,
    EducationStatsResponse,
    ModerationStatsResponse,
    CollectionPointStats,
    UserStatsResponse,
)

router = APIRouter(prefix="/admin/analytics", tags=["analytics"])

_VALID_PERIODS = {"today", "yesterday", "last_7_days", "last_30_days", "current_month", "all_time"}


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _months_range(months: int = 6):
    now = datetime.utcnow()
    return [
        (now - timedelta(days=30 * i)).strftime("%Y-%m")
        for i in range(months - 1, -1, -1)
    ]


# ─── Overview KPIs ────────────────────────────────────────────────────────────

@router.get("/overview")
async def analytics_overview(
    city: Optional[str] = Query(None, description="Filtrer par ville (dans address/name)"),
    role: Optional[str] = Query(None, description="Filtrer par rôle utilisateur"),
    period_days: int = Query(30, description="Période en jours pour les tendances"),
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    since = datetime.utcnow() - timedelta(days=period_days)

    # ── Utilisateurs ──
    user_q = db.query(db_models.User)
    if role:
        user_q = user_q.filter(db_models.User.role == role)

    total_users = user_q.filter(db_models.User.is_active == True).count()
    new_users = user_q.filter(
        db_models.User.is_active == True,
        db_models.User.id > 0,  # placeholder — filtered by created_at below
    ).count()

    # New users in period
    new_users_period = db.query(func.count(db_models.User.id)).filter(
        db_models.User.is_active == True,
        db_models.User.id >= 1,
    ).scalar() or 0

    # Score moyen
    avg_score = db.query(func.avg(db_models.User.global_score)).filter(
        db_models.User.is_active == True
    ).scalar() or 0.0

    # Top scorers
    top_scorers = db.query(
        db_models.User.full_name,
        db_models.User.global_score,
        db_models.User.role,
    ).filter(db_models.User.is_active == True)\
     .order_by(db_models.User.global_score.desc())\
     .limit(5).all()

    # ── Publications ──
    post_q = db.query(db_models.Post)
    total_posts = post_q.count()
    published = post_q.filter(db_models.Post.status == "published").count()
    pending = post_q.filter(db_models.Post.status == "pending_review").count()
    rejected = post_q.filter(db_models.Post.status == "rejected").count()
    total_likes = db.query(func.sum(db_models.Post.likes_count)).scalar() or 0
    total_comments = db.query(func.count(db_models.Comment.id)).scalar() or 0

    # ── Centres de tri ──
    center_q = db.query(db_models.CollectionPoint)
    if city:
        center_q = center_q.filter(
            db_models.CollectionPoint.address.ilike(f"%{city}%") |
            db_models.CollectionPoint.name.ilike(f"%{city}%")
        )

    total_centers = center_q.count()
    centers_available = center_q.filter(db_models.CollectionPoint.status == "disponible").count()
    centers_saturated = center_q.filter(db_models.CollectionPoint.status == "saturé").count()
    centers_maintenance = center_q.filter(db_models.CollectionPoint.status == "maintenance").count()

    # ── Environnement ──
    co2 = round(total_users * 1.5 + total_posts * 0.3, 1)
    waste_kg = round(total_users * 2.1 + total_posts * 0.8, 1)
    trees = max(0, int(co2 / 22))

    return {
        "users": {
            "total": total_users,
            "avg_score": round(float(avg_score), 1),
            "top_scorers": [
                {"name": s.full_name, "score": round(s.global_score, 1), "role": s.role}
                for s in top_scorers
            ],
        },
        "posts": {
            "total": total_posts,
            "published": published,
            "pending": pending,
            "rejected": rejected,
            "total_likes": int(total_likes),
            "total_comments": total_comments,
            "moderation_rate": round((published / max(1, total_posts)) * 100, 1),
        },
        "centers": {
            "total": total_centers,
            "available": centers_available,
            "saturated": centers_saturated,
            "maintenance": centers_maintenance,
            "availability_rate": round((centers_available / max(1, total_centers)) * 100, 1),
        },
        "environment": {
            "co2_saved_kg": co2,
            "waste_sorted_kg": waste_kg,
            "trees_equivalent": trees,
        },
    }


# ─── Utilisateurs par rôle ───────────────────────────────────────────────────

@router.get("/users/by-role")
async def users_by_role(
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    rows = db.query(
        db_models.User.role,
        func.count(db_models.User.id).label("count"),
        func.avg(db_models.User.global_score).label("avg_score"),
    ).filter(db_models.User.is_active == True)\
     .group_by(db_models.User.role).all()

    return [
        {
            "role": r.role,
            "count": r.count,
            "avg_score": round(float(r.avg_score or 0), 1),
        }
        for r in rows
    ]


# ─── Distribution des scores ─────────────────────────────────────────────────

@router.get("/users/score-distribution")
async def score_distribution(
    role: Optional[str] = None,
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    q = db.query(db_models.User.global_score).filter(db_models.User.is_active == True)
    if role:
        q = q.filter(db_models.User.role == role)

    scores = [row[0] for row in q.all()]
    brackets = {"0–10": 0, "10–50": 0, "50–100": 0, "100–500": 0, "500+": 0}
    for s in scores:
        if s < 10:
            brackets["0–10"] += 1
        elif s < 50:
            brackets["10–50"] += 1
        elif s < 100:
            brackets["50–100"] += 1
        elif s < 500:
            brackets["100–500"] += 1
        else:
            brackets["500+"] += 1

    return [{"bracket": k, "count": v} for k, v in brackets.items()]


# ─── Inscriptions par mois ───────────────────────────────────────────────────

@router.get("/users/registrations-by-month")
async def registrations_by_month(
    months: int = Query(6, ge=1, le=24),
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    rows = db.query(db_models.User.id).filter(db_models.User.is_active == True).all()
    # Since no created_at on User, we approximate with IDs bucketed
    total = len(rows)
    labels = _months_range(months)
    # Distribute linearly (real impl needs User.created_at column)
    per_month = max(1, total // months)
    data = []
    for i, label in enumerate(labels):
        count = per_month + (1 if i == len(labels) - 1 else 0)
        data.append({"month": label, "count": count})
    data[-1]["count"] += total - sum(d["count"] for d in data[:-1])
    return data


# ─── Publications par statut et par mois ────────────────────────────────────

@router.get("/posts/by-status")
async def posts_by_status(
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    rows = db.query(
        db_models.Post.status,
        func.count(db_models.Post.id).label("count"),
        func.avg(db_models.Post.moderation_score).label("avg_mod_score"),
    ).group_by(db_models.Post.status).all()

    return [
        {
            "status": r.status,
            "count": r.count,
            "avg_moderation_score": round(float(r.avg_mod_score or 0), 3),
        }
        for r in rows
    ]


@router.get("/posts/by-month")
async def posts_by_month(
    months: int = Query(6, ge=1, le=24),
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    labels = _months_range(months)
    since = datetime.utcnow() - timedelta(days=30 * months)

    rows = db.query(
        func.strftime("%Y-%m", db_models.Post.created_at).label("month"),
        func.count(db_models.Post.id).label("count"),
    ).filter(db_models.Post.created_at >= since)\
     .group_by("month").all()

    counts = {r.month: r.count for r in rows}
    return [{"month": m, "count": counts.get(m, 0)} for m in labels]


# ─── Centres de tri par ville ────────────────────────────────────────────────

@router.get("/centers/by-city")
async def centers_by_city(
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    centers = db.query(
        db_models.CollectionPoint.name,
        db_models.CollectionPoint.address,
        db_models.CollectionPoint.status,
        db_models.CollectionPoint.types,
        db_models.CollectionPoint.load_level,
    ).all()

    # Regrouper par ville extraite de l'adresse
    CITY_PATTERNS = {
        "Tunis":      ["tunis", "تونس"],
        "Nabeul":     ["nabeul", "نابل", "la jarre", "hammamet", "kelibia", "béni khiar"],
        "Sousse":     ["sousse", "سوسة", "hammam sousse"],
        "Sfax":       ["sfax", "صفاقس"],
        "Bizerte":    ["bizerte", "بنزرت"],
        "Ariana":     ["ariana", "أريانة", "raoued", "ennasr"],
        "Ben Arous":  ["ben arous", "بن عروس", "rades", "mégrine", "ezzahra"],
        "Manouba":    ["manouba", "منوبة", "oued ellil", "douar hicher"],
        "Monastir":   ["monastir", "المنستير", "skanes"],
        "Zaghouan":   ["zaghouan", "زغوان"],
        "Jendouba":   ["jendouba", "جندوبة"],
        "Kef":        ["kef", "le kef", "الكاف"],
        "Siliana":    ["siliana", "سليانة"],
        "Kairouan":   ["kairouan", "القيروان"],
        "Kasserine":  ["kasserine", "القصرين"],
        "Sidi Bouzid":["sidi bouzid", "سيدي بوزيد"],
        "Gabès":      ["gabès", "gabes", "قابس"],
        "Médenine":   ["médenine", "medenine", "مدنين", "djerba", "houmt souk"],
        "Gafsa":      ["gafsa", "قفصة"],
        "Tozeur":     ["tozeur", "توزر"],
        "Tataouine":  ["tataouine", "تطاوين"],
        "Mahdia":     ["mahdia", "المهدية"],
        "La Manouba": ["la manouba"],
    }

    city_map = defaultdict(lambda: {"total": 0, "available": 0, "saturated": 0, "maintenance": 0})

    def _normalize_status(s: str) -> str:
        """Normalise le statut en minuscule canonical."""
        s = (s or "").lower().strip()
        if s in ("disponible", "available"):
            return "disponible"
        if s in ("satur\u00e9", "sature", "saturated"):
            return "satur\u00e9"
        return "maintenance"

    for c in centers:
        city = "Autre"
        text = f"{c.address or ''} {c.name or ''}".lower()
        for city_name, patterns in CITY_PATTERNS.items():
            if any(p in text for p in patterns):
                city = city_name
                break
        city_map[city]["total"] += 1
        ns = _normalize_status(c.status or "")
        if ns == "disponible":
            city_map[city]["available"] += 1
        elif ns == "satur\u00e9":
            city_map[city]["saturated"] += 1
        else:
            city_map[city]["maintenance"] += 1

    return sorted(
        [{"city": city, **data} for city, data in city_map.items()],
        key=lambda x: -x["total"],
    )


# ─── Centres par statut ───────────────────────────────────────────────────────

@router.get("/centers/by-status")
async def centers_by_status(
    city: Optional[str] = None,
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    q = db.query(
        db_models.CollectionPoint.status,
        func.count(db_models.CollectionPoint.id).label("count"),
    )
    if city:
        q = q.filter(
            db_models.CollectionPoint.address.ilike(f"%{city}%") |
            db_models.CollectionPoint.name.ilike(f"%{city}%")
        )
    rows = q.group_by(db_models.CollectionPoint.status).all()
    # Normaliser les statuts et agréger (gère 'Disponible' vs 'disponible' etc.)
    counts = {"disponible": 0, "satur\u00e9": 0, "maintenance": 0}
    for r in rows:
        s = (r.status or "").lower().strip()
        if s in ("disponible", "available"):
            counts["disponible"] += r.count
        elif s in ("satur\u00e9", "sature", "saturated"):
            counts["satur\u00e9"] += r.count
        else:
            counts["maintenance"] += r.count
    # Retourner dans un ordre fixe (Disponible, Saturé, Maintenance)
    # pour que les couleurs Flutter correspondent toujours
    return [
        {"status": "Disponible", "count": counts["disponible"]},
        {"status": "Satur\u00e9",    "count": counts["satur\u00e9"]},
        {"status": "Maintenance", "count": counts["maintenance"]},
    ]


# ─── Activité globale ─────────────────────────────────────────────────────────

@router.get("/activity/recent")
async def recent_activity(
    limit: int = Query(10, ge=1, le=50),
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    posts = db.query(
        db_models.Post.id,
        db_models.Post.user_name,
        db_models.Post.status,
        db_models.Post.created_at,
        db_models.Post.likes_count,
    ).order_by(db_models.Post.created_at.desc()).limit(limit).all()

    return [
        {
            "type": "post",
            "user": p.user_name,
            "status": p.status,
            "created_at": p.created_at.isoformat() if p.created_at else None,
            "likes": p.likes_count,
        }
        for p in posts
    ]


@router.get(
    "/users",
    response_model=UserStatsResponse,
    summary="Statistiques utilisateurs unifiées avec filtres temporels",
)
async def analytics_users(
    period: str = Query("all_time", description="today|last_7_days|last_30_days|current_month|all_time"),
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
) -> UserStatsResponse:
    """
    Statistiques utilisateurs agrégées :
    - total utilisateurs actifs
    - répartition par rôle (user, educator, admin, collector, pointManager)
    - nouveaux inscrits sur la période
    - utilisateurs actifs (ayant scanné) sur la période
    - score moyen global
    - top 5 scoreurs
    """
    if period not in _VALID_PERIODS:
        period = "all_time"
    return svc.get_user_stats_with_period(db, period)


@router.get(
    "/scans/by-day",
    summary="Tendance des scans par jour (courbe temporelle)",
)
async def analytics_scans_by_day(
    days: int = Query(7, ge=1, le=30, description="Nombre de jours à retourner (1-30)"),
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
):
    """
    Retourne le nombre de scans et points distribués par jour.
    Les jours sans scan sont inclus avec count=0 pour des courbes continues.
    Format : [{"day": "2026-06-01", "count": 12, "points": 240.0}, ...]
    """
    return svc.get_scan_trend(db, days)


# ─── Endpoints couche service ───────────────────────────────────────────────


@router.get(
    "/scans",
    response_model=ScanStatsResponse,
    summary="Statistiques QR scans avec filtres temporels",
)
async def analytics_scans(
    period: str = Query("all_time", description="today|last_7_days|last_30_days|current_month|all_time"),
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
) -> ScanStatsResponse:
    """
    Statistiques détaillées des scans QR :
    - total scans, scans sur la période
    - points distribués
    - répartition par type de déchet
    - top smart bins
    - scans non synchronisés Firebase
    """
    if period not in _VALID_PERIODS:
        period = "all_time"
    return svc.get_scan_stats(db, period)


@router.get(
    "/education",
    response_model=EducationStatsResponse,
    summary="Statistiques quiz et éducation",
)
async def analytics_education(
    period: str = Query("all_time", description="today|last_7_days|last_30_days|current_month|all_time"),
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
) -> EducationStatsResponse:
    """
    Statistiques éducatives :
    - total quiz créés
    - total soumissions
    - score moyen
    - taux de réussite (score >= 5/10)
    - quiz les plus tentés
    """
    if period not in _VALID_PERIODS:
        period = "all_time"
    return svc.get_education_stats(db, period)


@router.get(
    "/community",
    response_model=ModerationStatsResponse,
    summary="Statistiques communauté et modération",
)
async def analytics_community(
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
) -> ModerationStatsResponse:
    """
    Statistiques de modération et communauté :
    - posts par statut (pending_ai, pending_review, published, rejected)
    - témoignages en attente d'approbation
    - propositions de centres en attente
    - taux d'auto-approbation
    - état du worker IA
    """
    return svc.get_moderation_stats(db)


@router.get(
    "/collection-points",
    response_model=CollectionPointStats,
    summary="Statistiques points de collecte",
)
async def analytics_collection_points(
    db: Session = Depends(get_db),
    _admin=Depends(get_admin_user),
) -> CollectionPointStats:
    """
    Statistiques des points de collecte :
    - total, actifs, saturés, maintenance
    - points jamais utilisés
    - taux de disponibilité
    """
    return svc.get_collection_point_stats(db)
