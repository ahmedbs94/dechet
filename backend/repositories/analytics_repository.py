"""
repositories/analytics_repository.py — Couche d'accès aux données analytiques
===============================================================================
Contient UNIQUEMENT des requêtes SQL agrégées.
Aucune logique métier ici — déléguer à admin_analytics_service.py.
"""
from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Tuple

from sqlalchemy import func, and_, distinct
from sqlalchemy.orm import Session

import db_models as m


# ── Helpers date ──────────────────────────────────────────────────────────────

def _since(period: Optional[str]) -> Optional[datetime]:
    """Convertit un label de période en datetime UTC de début.

    Règles :
      today          → minuit UTC aujourd'hui
      yesterday      → minuit UTC d'hier (inclut hier complet, jusqu'à maintenant)
      last_7_days    → il y a 7 jours·
      last_30_days   → il y a 30 jours
      current_month  → 1er du mois en cours
      all_time       → None (pas de filtre)
    """
    if period is None or period == "all_time":
        return None
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    today_midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)

    if period == "today":
        return today_midnight
    if period == "yesterday":
        return today_midnight - timedelta(days=1)   # minuit d'hier → inclut hier complet
    if period == "current_month":
        return today_midnight.replace(day=1)

    days_map = {
        "last_7_days":  7,
        "last_30_days": 30,
    }
    days = days_map.get(period, 30)
    return now - timedelta(days=days)


# ── Utilisateurs ──────────────────────────────────────────────────────────────

def count_total_users(db: Session) -> int:
    return db.query(func.count(m.User.id)).filter(m.User.is_active == True).scalar() or 0


def count_users_by_role(db: Session) -> Dict[str, int]:
    rows = (
        db.query(m.User.role, func.count(m.User.id))
        .filter(m.User.is_active == True)
        .group_by(m.User.role)
        .all()
    )
    return {role: count for role, count in rows}


def count_new_users(db: Session, since: Optional[datetime]) -> int:
    q = db.query(func.count(m.User.id)).filter(m.User.is_active == True)
    if since:
        q = q.filter(m.User.created_at >= since)
    return q.scalar() or 0


def count_active_users(db: Session, since: Optional[datetime]) -> int:
    """Utilisateurs ayant fait au moins un scan sur la période."""
    q = db.query(func.count(distinct(m.BinScan.user_id)))
    if since:
        q = q.filter(m.BinScan.scanned_at >= since)
    return q.scalar() or 0


def get_average_score(db: Session) -> float:
    return float(
        db.query(func.avg(m.User.global_score))
        .filter(m.User.is_active == True)
        .scalar() or 0.0
    )


def get_top_scorers(db: Session, limit: int = 5) -> list:
    return (
        db.query(m.User.full_name, m.User.global_score, m.User.role)
        .filter(m.User.is_active == True)
        .order_by(m.User.global_score.desc())
        .limit(limit)
        .all()
    )


# ── Scans QR ─────────────────────────────────────────────────────────────────

def count_total_scans(db: Session, since: Optional[datetime] = None) -> int:
    q = db.query(func.count(m.BinScan.id))
    if since:
        q = q.filter(m.BinScan.scanned_at >= since)
    return q.scalar() or 0


def sum_points_distributed(db: Session, since: Optional[datetime] = None) -> float:
    q = db.query(func.sum(m.BinScan.points_earned))
    if since:
        q = q.filter(m.BinScan.scanned_at >= since)
    return float(q.scalar() or 0.0)


def count_scans_by_waste_type(db: Session, since: Optional[datetime] = None) -> list:
    q = (
        db.query(
            m.BinScan.waste_type,
            func.count(m.BinScan.id).label("count"),
            func.coalesce(func.sum(m.BinScan.points_earned), 0).label("points"),
        )
        .group_by(m.BinScan.waste_type)
        .order_by(func.count(m.BinScan.id).desc())
    )
    if since:
        q = q.filter(m.BinScan.scanned_at >= since)
    return q.all()


def get_top_bins(db: Session, since: Optional[datetime] = None, limit: int = 5) -> list:
    q = (
        db.query(
            m.BinScan.smart_bin_id,
            func.count(m.BinScan.id).label("scans_count"),
            func.coalesce(func.sum(m.BinScan.points_earned), 0).label("points_earned"),
        )
        .filter(m.BinScan.smart_bin_id.isnot(None))
        .group_by(m.BinScan.smart_bin_id)
        .order_by(func.count(m.BinScan.id).desc())
        .limit(limit)
    )
    if since:
        q = q.filter(m.BinScan.scanned_at >= since)
    return q.all()


def count_firebase_unsynced(db: Session) -> int:
    return (
        db.query(func.count(m.BinScan.id))
        .filter(m.BinScan.firebase_synced == False)
        .scalar() or 0
    )


def average_points_per_scan(db: Session, since: Optional[datetime] = None) -> float:
    q = db.query(func.avg(m.BinScan.points_earned))
    if since:
        q = q.filter(m.BinScan.scanned_at >= since)
    return float(q.scalar() or 0.0)


def count_scans_by_day(db: Session, days: int = 7) -> List[dict]:
    """Retourne le nombre de scans par jour sur les N derniers jours.
    Complète les jours sans données avec count=0 pour des courbes continues.
    """
    since = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days)
    rows = (
        db.query(
            func.date(m.BinScan.scanned_at).label("day"),
            func.count(m.BinScan.id).label("count"),
            func.coalesce(func.sum(m.BinScan.points_earned), 0).label("points"),
        )
        .filter(m.BinScan.scanned_at >= since)
        .group_by(func.date(m.BinScan.scanned_at))
        .order_by(func.date(m.BinScan.scanned_at))
        .all()
    )
    # Construire un dict jour → données
    data_map: Dict[str, dict] = {
        str(r.day): {"day": str(r.day), "count": r.count, "points": float(r.points)}
        for r in rows
    }
    # Compléter les jours manquants
    result = []
    for i in range(days):
        day = (datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days - 1 - i)).date()
        day_str = str(day)
        result.append(data_map.get(day_str, {"day": day_str, "count": 0, "points": 0.0}))
    return result


# ── Points de collecte ────────────────────────────────────────────────────────

def count_collection_points_by_status(db: Session) -> Dict[str, int]:
    rows = (
        db.query(m.CollectionPoint.status, func.count(m.CollectionPoint.id))
        .group_by(m.CollectionPoint.status)
        .all()
    )
    result: Dict[str, int] = {"disponible": 0, "saturé": 0, "maintenance": 0}
    for status, count in rows:
        s = (status or "").lower().strip()
        if s in ("disponible", "available"):
            result["disponible"] += count
        elif s in ("saturé", "sature", "saturated"):
            result["saturé"] += count
        else:
            result["maintenance"] += count
    return result


def count_unused_collection_points(db: Session) -> int:
    """Points de collecte sans aucun SmartBin scanné."""
    used_ids = (
        db.query(distinct(m.SmartBin.collection_point_id))
        .join(m.BinScan, m.BinScan.smart_bin_id == m.SmartBin.id)
        .filter(m.SmartBin.collection_point_id.isnot(None))
        .subquery()
    )
    return (
        db.query(func.count(m.CollectionPoint.id))
        .filter(m.CollectionPoint.id.notin_(used_ids))
        .scalar() or 0
    )


# ── Quiz / Éducation ──────────────────────────────────────────────────────────

def count_total_quizzes(db: Session) -> int:
    return db.query(func.count(m.Quiz.id)).scalar() or 0


def count_quiz_submissions(db: Session, since: Optional[datetime] = None) -> int:
    q = db.query(func.count(m.QuizSubmission.id))
    if since:
        q = q.filter(m.QuizSubmission.submitted_at >= since)
    return q.scalar() or 0


def average_quiz_score(db: Session, since: Optional[datetime] = None) -> float:
    q = db.query(func.avg(m.QuizSubmission.score))
    if since:
        q = q.filter(m.QuizSubmission.submitted_at >= since)
    return float(q.scalar() or 0.0)


def quiz_success_rate(db: Session, pass_score: float = 5.0,
                      since: Optional[datetime] = None) -> float:
    """Taux de réussite : % soumissions avec score >= pass_score."""
    total_q = db.query(func.count(m.QuizSubmission.id))
    pass_q  = db.query(func.count(m.QuizSubmission.id)).filter(
        m.QuizSubmission.score >= pass_score
    )
    if since:
        total_q = total_q.filter(m.QuizSubmission.submitted_at >= since)
        pass_q  = pass_q.filter(m.QuizSubmission.submitted_at >= since)
    total = total_q.scalar() or 0
    passed = pass_q.scalar() or 0
    return round((passed / total * 100), 1) if total > 0 else 0.0


def get_top_quizzes(db: Session, limit: int = 5) -> list:
    return (
        db.query(
            m.Quiz.id,
            m.Quiz.title,
            func.count(m.QuizSubmission.id).label("submissions"),
            func.avg(m.QuizSubmission.score).label("avg_score"),
        )
        .outerjoin(m.QuizSubmission, m.QuizSubmission.quiz_id == m.Quiz.id)
        .group_by(m.Quiz.id, m.Quiz.title)
        .order_by(func.count(m.QuizSubmission.id).desc())
        .limit(limit)
        .all()
    )


# ── Modération ────────────────────────────────────────────────────────────────

def count_posts_by_status(db: Session) -> Dict[str, int]:
    rows = (
        db.query(m.Post.status, func.count(m.Post.id))
        .group_by(m.Post.status)
        .all()
    )
    return {status: count for status, count in rows}


def count_pending_testimonials(db: Session) -> int:
    return (
        db.query(func.count(m.Testimonial.id))
        .filter(m.Testimonial.is_approved == False)
        .scalar() or 0
    )


def count_pending_center_proposals(db: Session) -> int:
    return (
        db.query(func.count(m.CenterProposal.id))
        .filter(m.CenterProposal.status == "pending")
        .scalar() or 0
    )


# ── Anomalies ─────────────────────────────────────────────────────────────────

def detect_high_scan_rate_users(db: Session, max_per_hour: int = 20) -> list:
    """Utilisateurs ayant scanné plus de max_per_hour fois dans la dernière heure."""
    since_1h = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(hours=1)
    rows = (
        db.query(
            m.BinScan.user_id,
            func.count(m.BinScan.id).label("scan_count"),
        )
        .filter(m.BinScan.scanned_at >= since_1h)
        .group_by(m.BinScan.user_id)
        .having(func.count(m.BinScan.id) > max_per_hour)
        .all()
    )
    return rows


def detect_repeated_bin_scans(db: Session, max_same_bin: int = 10) -> list:
    """Même utilisateur scannant le même bin plus de max_same_bin fois aujourd'hui."""
    since_today = datetime.now(timezone.utc).replace(tzinfo=None).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    rows = (
        db.query(
            m.BinScan.user_id,
            m.BinScan.smart_bin_id,
            func.count(m.BinScan.id).label("count"),
        )
        .filter(
            m.BinScan.scanned_at >= since_today,
            m.BinScan.smart_bin_id.isnot(None),
        )
        .group_by(m.BinScan.user_id, m.BinScan.smart_bin_id)
        .having(func.count(m.BinScan.id) > max_same_bin)
        .all()
    )
    return rows
