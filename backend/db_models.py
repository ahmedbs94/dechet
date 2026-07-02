"""
db_models.py — Shim de rétrocompatibilité (Phase 1 de la refactorisation)
═══════════════════════════════════════════════════════════════════════════
Ce fichier ré-exporte toutes les classes SQLAlchemy depuis leur nouveau
emplacement canonique dans app/*/models.py.

Les 14 routers qui font `import db_models` continuent de fonctionner
sans aucune modification.

Phase 2 (future) : mettre à jour les imports dans chaque router pour
pointer directement vers app/*/models, puis supprimer ce fichier.
"""

# ── Users ─────────────────────────────────────────────────────────────────────
from app.users.models import User, generate_unique_qr_token  # noqa: F401

# ── Auth ──────────────────────────────────────────────────────────────────────
from app.auth.models import OTPCode  # noqa: F401

# ── Posts ─────────────────────────────────────────────────────────────────────
from app.posts.models import Post, SavedPost, Like, Comment  # noqa: F401

# ── Notifications ─────────────────────────────────────────────────────────────
from app.notifications.models import Notification  # noqa: F401

# ── Collection Points ─────────────────────────────────────────────────────────
from app.collection_points.models import CollectionPoint  # noqa: F401

# ── Community ─────────────────────────────────────────────────────────────────
from app.community.models import Testimonial, CenterProposal  # noqa: F401

# ── Quiz ──────────────────────────────────────────────────────────────────────
from app.quiz.models import Quiz, QuizSubmission  # noqa: F401

# ── Education ─────────────────────────────────────────────────────────────────
from app.education.models import (  # noqa: F401
    VideoCategory,
    EducatorVideo,
    CitizenGroup,
    GroupMember,
    Meeting,
    MeetingParticipant,
)

# ── QR Bins ───────────────────────────────────────────────────────────────────
from app.qr_bins.models import SmartBin, BinScan, CollectorLog  # noqa: F401

# ── Intercommunalité ──────────────────────────────────────────────────────────
from app.intercommunality.models import LocalInstruction, CustomActorGroup  # noqa: F401
from app.intercommunality.zone_models import CollectorZone, CollectorZoneAssignment  # noqa: F401

# ── Signalements citoyens ─────────────────────────────────────────────────────
from app.reports.models import CitizenReport  # noqa: F401

# ── Tournées de collecte ──────────────────────────────────────────────────────
from app.collector_routes.models import CollectionRoute  # noqa: F401
