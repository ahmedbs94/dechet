"""
services/admin_analytics_service.py — Orchestration des statistiques admin
===========================================================================
Orchestre les appels au repository et assemble les réponses Pydantic.
Aucune requête SQL directe ici.
"""
from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from sqlalchemy.orm import Session

from repositories import analytics_repository as repo
from repositories.analytics_repository import _since
from schemas.admin_analytics import (
    AdminDashboardResponse,
    CollectionPointStats,
    DashboardSummary,
    EducationStatsResponse,
    ModerationStatsResponse,
    ScanStatsResponse,
    TopBin,
    TopQuiz,
    TopScorer,
    UsersByRole,
    UserStatsResponse,
    WasteTypeCount,
)

# Titres de quiz à exclure des statistiques (quiz de test / internes)
_QUIZ_EXCLUSIONS = {"environnement_question", "environnement_questions"}


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


# ── Utilisateurs ──────────────────────────────────────────────────────────────

def get_user_stats(db: Session, period: Optional[str] = "all_time") -> UserStatsResponse:
    since = _since(period)
    by_role_raw = repo.count_users_by_role(db)
    top_raw = repo.get_top_scorers(db, limit=5)

    return UserStatsResponse(
        total=repo.count_total_users(db),
        by_role=UsersByRole(
            user=by_role_raw.get("user", 0),
            educator=by_role_raw.get("educator", 0),
            admin=by_role_raw.get("admin", 0),
            collector=by_role_raw.get("collector", 0),
            point_manager=by_role_raw.get("pointManager", 0),
        ),
        new_this_period=repo.count_new_users(db, since),
        active_this_period=repo.count_active_users(db, since),
        average_global_score=round(repo.get_average_score(db), 1),
        top_scorers=[
            TopScorer(
                name=r.full_name or "Anonyme",
                score=round(r.global_score or 0.0, 1),
                role=r.role or "user",
            )
            for r in top_raw
        ],
    )


# ── Scans QR ─────────────────────────────────────────────────────────────────

def get_scan_stats(db: Session, period: Optional[str] = "all_time") -> ScanStatsResponse:
    since = _since(period)

    waste_rows = repo.count_scans_by_waste_type(db, since)
    top_bins_raw = repo.get_top_bins(db, since, limit=5)

    return ScanStatsResponse(
        total=repo.count_total_scans(db),
        this_period=repo.count_total_scans(db, since),
        points_distributed=round(repo.sum_points_distributed(db, since), 1),
        by_waste_type=[
            WasteTypeCount(
                waste_type=r.waste_type or "général",
                count=r.count,
                points=round(float(r.points or 0), 1),
            )
            for r in waste_rows
        ],
        top_bins=[
            TopBin(
                smart_bin_id=r.smart_bin_id,
                bin_code=None,
                collection_point=None,
                scans_count=r.scans_count,
                points_earned=round(float(r.points_earned or 0), 1),
            )
            for r in top_bins_raw
        ],
        average_points_per_scan=round(repo.average_points_per_scan(db, since), 2),
    )


def get_scan_trend(db: Session, days: int = 7) -> List[dict]:
    """Retourne les scans par jour pour le graphique courbe."""
    return repo.count_scans_by_day(db, days)


# ── Utilisateurs (endpoint unifié) ───────────────────────────────────────────

def get_user_stats_with_period(db: Session, period: Optional[str] = "all_time") -> UserStatsResponse:
    """Endpoint unifié /admin/analytics/users avec filtre period string."""
    since = _since(period)
    by_role_raw = repo.count_users_by_role(db)
    top_raw = repo.get_top_scorers(db, limit=5)

    return UserStatsResponse(
        total=repo.count_total_users(db),
        by_role=UsersByRole(
            user=by_role_raw.get("user", 0),
            educator=by_role_raw.get("educator", 0),
            admin=by_role_raw.get("admin", 0),
            collector=by_role_raw.get("collector", 0),
            point_manager=by_role_raw.get("pointManager", 0),
        ),
        new_this_period=repo.count_new_users(db, since),
        active_this_period=repo.count_active_users(db, since),
        average_global_score=round(repo.get_average_score(db), 1),
        top_scorers=[
            TopScorer(
                name=r.full_name or "Anonyme",
                score=round(r.global_score or 0.0, 1),
                role=r.role or "user",
            )
            for r in top_raw
        ],
    )


# ── Points de collecte ────────────────────────────────────────────────────────

def get_collection_point_stats(db: Session) -> CollectionPointStats:
    by_status = repo.count_collection_points_by_status(db)
    total = sum(by_status.values())
    active = by_status.get("disponible", 0)
    return CollectionPointStats(
        total=total,
        active=active,
        saturated=by_status.get("saturé", 0),
        maintenance=by_status.get("maintenance", 0),
        unused=repo.count_unused_collection_points(db),
        availability_rate=round((active / total * 100), 1) if total > 0 else 0.0,
    )


# ── Éducation ─────────────────────────────────────────────────────────────────

def get_education_stats(db: Session, period: Optional[str] = "all_time") -> EducationStatsResponse:
    since = _since(period)
    top_quizzes_raw = repo.get_top_quizzes(db, limit=10)  # récupérer plus pour filtrer

    # Exclure les quiz internes / de test
    top_quizzes_filtered = [
        r for r in top_quizzes_raw
        if (r.title or "").lower().strip() not in _QUIZ_EXCLUSIONS
    ][:5]

    return EducationStatsResponse(
        total_quizzes=repo.count_total_quizzes(db),
        total_submissions=repo.count_quiz_submissions(db, since),
        average_quiz_score=round(repo.average_quiz_score(db, since), 1),
        success_rate=repo.quiz_success_rate(db, since=since),
        most_attempted=[
            TopQuiz(
                quiz_id=r.id,
                title=r.title or "—",
                submissions=r.submissions or 0,
                avg_score=round(float(r.avg_score), 1) if r.avg_score else None,
            )
            for r in top_quizzes_filtered
        ],
    )


# ── Modération ────────────────────────────────────────────────────────────────

def get_moderation_stats(db: Session) -> ModerationStatsResponse:
    posts = repo.count_posts_by_status(db)
    total = sum(posts.values())
    published = posts.get("published", 0)
    pending_ai = posts.get("pending_ai", 0)
    pending_review = posts.get("pending_review", 0)

    return ModerationStatsResponse(
        pending_ai=pending_ai,
        pending_review=pending_review,
        published=published,
        rejected=posts.get("rejected", 0),
        total_posts=total,
        pending_testimonials=repo.count_pending_testimonials(db),
        pending_center_proposals=repo.count_pending_center_proposals(db),
    )


# ── Dashboard complet ─────────────────────────────────────────────────────────

def get_dashboard_summary(db: Session) -> AdminDashboardResponse:
    """
    Agrège toutes les statistiques en un seul appel.
    Flutter n'a besoin que de GET /admin/dashboard pour charger les cartes.
    """
    since_week  = _now() - timedelta(days=7)
    since_today = _now().replace(hour=0, minute=0, second=0, microsecond=0)
    since_month = _now() - timedelta(days=30)

    by_role_raw = repo.count_users_by_role(db)
    posts       = repo.count_posts_by_status(db)
    by_status   = repo.count_collection_points_by_status(db)

    pending_ai     = posts.get("pending_ai", 0)
    pending_review = posts.get("pending_review", 0)

    summary = DashboardSummary(
        # Utilisateurs
        total_users=repo.count_total_users(db),
        users_by_role=UsersByRole(
            user=by_role_raw.get("user", 0),
            educator=by_role_raw.get("educator", 0),
            admin=by_role_raw.get("admin", 0),
            collector=by_role_raw.get("collector", 0),
            point_manager=by_role_raw.get("pointManager", 0),
        ),
        new_users_this_month=repo.count_new_users(db, since_month),
        active_users_this_week=repo.count_active_users(db, since_week),
        average_global_score=round(repo.get_average_score(db), 1),

        # Scans QR
        total_bin_scans=repo.count_total_scans(db),
        scans_today=repo.count_total_scans(db, since_today),
        scans_this_week=repo.count_total_scans(db, since_week),
        points_distributed=round(repo.sum_points_distributed(db), 1),

        # Points de collecte
        total_collection_points=sum(by_status.values()),
        active_collection_points=by_status.get("disponible", 0),

        # Éducation
        total_quiz_submissions=repo.count_quiz_submissions(db),
        average_quiz_score=round(repo.average_quiz_score(db), 1),

        # Modération
        pending_moderation=pending_ai + pending_review,
        pending_testimonials=repo.count_pending_testimonials(db),
        pending_center_proposals=repo.count_pending_center_proposals(db),
    )

    return AdminDashboardResponse(
        success=True,
        data=summary,
        period="all_time",
        updated_at=_now(),
        message="Admin dashboard loaded",
    )
