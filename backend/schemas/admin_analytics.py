"""
schemas/admin_analytics.py — Schémas Pydantic pour le dashboard admin analytics
================================================================================
Garantit des réponses JSON normalisées et typées pour tous les endpoints admin.
"""
from __future__ import annotations
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


# ── Filtre temporel ────────────────────────────────────────────────────────────

PERIOD_DAYS: Dict[str, Optional[int]] = {
    "today":          1,
    "yesterday":      1,
    "last_7_days":    7,
    "last_30_days":   30,
    "current_month":  30,
    "all_time":       None,
}


# ── Utilisateurs ──────────────────────────────────────────────────────────────

class UsersByRole(BaseModel):
    user:           int = 0
    educator:       int = 0
    admin:          int = 0
    collector:      int = 0
    point_manager:  int = 0

class TopScorer(BaseModel):
    name:  str
    score: float
    role:  str

class UserStatsResponse(BaseModel):
    total:                  int
    by_role:                UsersByRole
    new_this_period:        int
    active_this_period:     int
    average_global_score:   float
    top_scorers:            List[TopScorer] = []


# ── Scans QR / Smart Bins ─────────────────────────────────────────────────────

class WasteTypeCount(BaseModel):
    waste_type: str
    count:      int
    points:     float

class TopBin(BaseModel):
    smart_bin_id:    Optional[int]
    bin_code:        Optional[str]
    collection_point: Optional[str]
    scans_count:     int
    points_earned:   float

class ScanStatsResponse(BaseModel):
    total:               int
    this_period:         int
    points_distributed:  float
    by_waste_type:       List[WasteTypeCount] = []
    top_bins:            List[TopBin] = []
    firebase_unsynced:   int
    average_points_per_scan: float


# ── Points de collecte ────────────────────────────────────────────────────────

class CollectionPointStats(BaseModel):
    total:      int
    active:     int       # status = disponible
    saturated:  int
    maintenance: int
    unused:     int       # points sans aucun scan
    availability_rate: float  # %


# ── Quiz / Éducation ──────────────────────────────────────────────────────────

class TopQuiz(BaseModel):
    quiz_id:     int
    title:       str
    submissions: int
    avg_score:   Optional[float]

class EducationStatsResponse(BaseModel):
    total_quizzes:       int
    total_submissions:   int
    average_quiz_score:  float
    success_rate:        float    # % soumissions avec score >= 5
    most_attempted:      List[TopQuiz] = []


# ── Modération / Communauté ───────────────────────────────────────────────────

class ModerationStatsResponse(BaseModel):
    pending_ai:              int
    pending_review:          int
    published:               int
    rejected:                int
    total_posts:             int
    pending_testimonials:    int
    pending_center_proposals: int
    auto_approve_rate:       float
    worker_health:           str   # "ok" | "warning" | "critical"


# ── Anomalies ─────────────────────────────────────────────────────────────────

class Anomaly(BaseModel):
    type:        str           # SCAN_RATE_LIMIT | FIREBASE_UNSYNCED | etc.
    severity:    str           # low | medium | high | critical
    user_id:     Optional[int] = None
    message:     str
    value:       Any = None
    detected_at: datetime

class AnomaliesResponse(BaseModel):
    count:     int
    anomalies: List[Anomaly] = []


# ── Dashboard summary (1 seul appel Flutter) ──────────────────────────────────

class DashboardSummary(BaseModel):
    # Utilisateurs
    total_users:            int
    users_by_role:          UsersByRole
    new_users_this_month:   int
    active_users_this_week: int
    average_global_score:   float

    # Scans QR
    total_bin_scans:        int
    scans_today:            int
    scans_this_week:        int
    points_distributed:     float
    firebase_unsynced_scans: int

    # Points de collecte
    total_collection_points:  int
    active_collection_points: int

    # Éducation
    total_quiz_submissions: int
    average_quiz_score:     float

    # Modération
    pending_moderation:     int   # pending_ai + pending_review
    pending_testimonials:   int
    pending_center_proposals: int

    # Anomalies
    anomalies_count:        int

class AdminDashboardResponse(BaseModel):
    success:    bool = True
    data:       DashboardSummary
    period:     str = "all_time"
    updated_at: datetime
    message:    str = "Admin dashboard loaded"
