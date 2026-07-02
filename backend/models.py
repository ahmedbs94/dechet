"""
models.py — Shim de rétrocompatibilité (Phase 2 de la refactorisation)
═══════════════════════════════════════════════════════════════════════
Ce fichier ré-exporte tous les schémas Pydantic depuis leur nouveau
emplacement canonique dans app/*/schemas.py.

Les routers qui font `from models import ...` continuent de fonctionner
sans aucune modification.

Phase 3 (future) : mettre à jour les imports dans chaque router pour
pointer directement vers app/*/schemas, puis supprimer ce fichier.
"""

# ── Users ─────────────────────────────────────────────────────────────────────
from app.users.schemas import (  # noqa: F401
    UserBase,
    UserCreate,
    UserOut as User,
    UserSmall,
    UserUpdate,
    ChangePasswordRequest,
    MFASetupResponse,
    MFAVerifyEnableRequest,
    MFADisableRequest,
)

# ── Auth ──────────────────────────────────────────────────────────────────────
from app.auth.schemas import (  # noqa: F401
    Token,
    RefreshTokenRequest,
    TokenData,
    GoogleAuth,
    FacebookAuth,
    ForgotPassword,
    ResetPassword,
    VerifyResetCode,
    OTPSendRequest,
    OTPVerifyRequest,
    QRVerifyRequest,
    MFAPendingResponse,
    MFAVerifyLoginRequest,
)

# ── Posts ─────────────────────────────────────────────────────────────────────
from app.posts.schemas import (  # noqa: F401
    PostBase,
    PostCreate,
    PostOut as Post,
    PostUpdate,
    CommentBase,
    CommentCreate,
    CommentOut as Comment,
    CommentUpdate,
)

# ── Notifications ─────────────────────────────────────────────────────────────
from app.notifications.schemas import NotificationOut  # noqa: F401

# ── Collection Points ─────────────────────────────────────────────────────────
from app.collection_points.schemas import (  # noqa: F401
    CollectionPointCreate,
    CollectionPointUpdate,
    CollectionPointOut as CollectionPointResponse,
)

# ── Community ─────────────────────────────────────────────────────────────────
from app.community.schemas import (  # noqa: F401
    TestimonialCreate,
    TestimonialOut as TestimonialResponse,
    CenterProposalCreate,
    CenterProposalOut as CenterProposalResponse,
)

# ── QR Bins ───────────────────────────────────────────────────────────────────
from app.qr_bins.schemas import (  # noqa: F401
    BinScanRequest,
    BinScanResponse,
    SmartBinCreate,
    SmartBinUpdate,
    SmartBinOut,
    BinScanOut,
)
