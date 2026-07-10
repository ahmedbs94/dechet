"""
EcoRewind Backend — Application Factory
========================================
main.py est maintenant réduit à son strict minimum :
  - Création de l'app FastAPI
  - Configuration CORS & fichiers statiques
  - Inclusion des routers modulaires

Architecture feature-based (app/) :
  app/users/       → User (SQLAlchemy) + UserOut, UserCreate… (Pydantic)
  app/auth/        → OTPCode + Token, ResetPassword… + service JWT
  app/posts/       → Post, Like, Comment… + schemas
  app/notifications/ → Notification + schemas
  app/collection_points/ → CollectionPoint + schemas
  app/community/   → Testimonial, CenterProposal + schemas
  app/quiz/        → Quiz, QuizSubmission + schemas
  app/education/   → VideoCategory, EducatorVideo, CitizenGroup… + schemas
  app/qr_bins/     → SmartBin, BinScan + schemas
  app/firebase/    → service Firebase Admin SDK

Routers (conservés dans routers/ — Phase 3 future) :
  auth.py            → /register, /token, /otp/*, /auth/*, /forgot-password…
  users.py           → /users, /admin/users/*, /users/me*
  posts.py           → /posts/*, /upload, /comments/*, /users/me/saved-posts
  notifications.py   → /notifications/*
  collection_points.py → /collection-points, /admin/collection-points/*
  community.py       → /testimonials/*, /center-proposals/*, /stats…
  qr_bins.py         → /qr/scan-bin, /qr/scan-history, /qr/smart-bins…
"""

from dotenv import load_dotenv
load_dotenv()

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

# ── Schéma DB géré par Alembic ────────────────────────────────────────────────
# Les tables sont créées/migrées via : alembic upgrade head
# NE PAS appeler Base.metadata.create_all() ici — cela contourne les migrations.
import db_models  # noqa: F401 — importe tous les modèles pour que Base.metadata les connaisse

# ── App factory ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="EcoRewind API",
    description="Backend REST API for the EcoRewind waste sorting platform.",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── Static files ───────────────────────────────────────────────────────────────
UPLOADS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

# ── CORS ───────────────────────────────────────────────────────────────────────
IS_DEV = os.getenv("APP_ENV", "development").lower() != "production"
_raw = os.getenv("CORS_ORIGINS", "")
if _raw == "*" and IS_DEV:
    _origins = ["*"]
elif _raw:
    _origins = [o.strip() for o in _raw.split(",") if o.strip()]
else:
    _origins = ["http://localhost:3000", "http://localhost:8080", "http://localhost:5500"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Include routers ────────────────────────────────────────────────────────────
from routers import auth, users, posts, notifications, collection_points, community, moderation, quiz, educator_videos, qr_bins, meetings, groups, analytics, admin_dashboard, intercommunality, point_manager, collector_routes, messaging  # noqa: E402

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(posts.router)
app.include_router(notifications.router)
app.include_router(collection_points.router)
app.include_router(community.router)
app.include_router(moderation.router)
app.include_router(quiz.router)
app.include_router(educator_videos.router)
app.include_router(qr_bins.router)
app.include_router(meetings.router)
app.include_router(groups.router)
app.include_router(analytics.router)
app.include_router(admin_dashboard.router)  # GET /admin/dashboard

# ── Routers des 3 acteurs métier ───────────────────────────────────────────────
app.include_router(intercommunality.router)   # /intercommunality/*
app.include_router(point_manager.router)      # /point-manager/* + /citizen/report*
app.include_router(collector_routes.router)   # /collector/*
app.include_router(messaging.router)          # /messages/*

# Note: /uploads est déjà monté ci-dessus (ligne 44). Pas de doublon.


# ── NOTE : Modèles IA ─────────────────────────────────────────────────────────
# Les modèles IA NE sont plus chargés dans FastAPI.
# Ils tournent dans un processus séparé : backend/ai_worker/worker.py
#
# Démarrage du worker IA :
#   python -m ai_worker.worker
#
# Avantage : avec --workers 4, les modèles ne sont chargés qu'UNE SEULE FOIS
# au lieu de 4 fois (évite 4x la RAM).


# ── Startup : vérification des migrations Alembic ─────────────────────────────
@app.on_event("startup")
async def _check_migrations():
    """
    Vérifie au démarrage que la DB est à la dernière migration Alembic.
    Évite les crashs silencieux causés par des tables/colonnes manquantes
    quand quelqu'un déploie sans exécuter 'alembic upgrade head'.
    """
    try:
        from alembic.config import Config
        from alembic.runtime.migration import MigrationContext
        from alembic.script import ScriptDirectory
        from database import engine

        alembic_cfg_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "alembic.ini")
        alembic_cfg = Config(alembic_cfg_path)
        script = ScriptDirectory.from_config(alembic_cfg)

        with engine.connect() as conn:
            context = MigrationContext.configure(conn)
            current_rev = set(context.get_current_heads())
            head_rev    = set(script.get_heads())

        if current_rev == head_rev:
            print(f"[STARTUP] [OK] Migrations Alembic à jour — revision : {', '.join(head_rev)}")
        else:
            print(f"[STARTUP] [WARN] ⚠️  Migrations en retard !")
            print(f"  DB actuelle : {current_rev or 'aucune'}")
            print(f"  Head requis : {head_rev}")
            print(f"  → Exécuter : migrate.bat up  (ou alembic upgrade head)")
    except Exception as e:
        print(f"[STARTUP] [WARN] Vérification migrations impossible : {e}")


# ── Health check ───────────────────────────────────────────────────────────────
@app.get("/", tags=["health"])
async def root():
    return {"status": "ok", "service": "EcoRewind API", "version": "2.0.0"}


@app.get("/health", tags=["health"])
async def health():
    """Health check enrichi : DB + statut migrations."""
    try:
        from alembic.config import Config
        from alembic.runtime.migration import MigrationContext
        from alembic.script import ScriptDirectory
        from database import engine

        alembic_cfg_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "alembic.ini")
        alembic_cfg = Config(alembic_cfg_path)
        script = ScriptDirectory.from_config(alembic_cfg)

        with engine.connect() as conn:
            context = MigrationContext.configure(conn)
            current_rev = list(context.get_current_heads())
            head_rev    = list(script.get_heads())

        migrations_ok = set(current_rev) == set(head_rev)
        return {
            "status":          "ok" if migrations_ok else "degraded",
            "service":         "EcoRewind API",
            "version":         "2.0.0",
            "db":              "connected",
            "migrations":      "up-to-date" if migrations_ok else "PENDING",
            "current_rev":     current_rev,
            "head_rev":        head_rev,
        }
    except Exception as e:
        return {"status": "error", "detail": str(e)}
