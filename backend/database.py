"""
database.py — Connexion SQLAlchemy
===================================
Politique de base de données :
  - PRODUCTION / STAGING : PostgreSQL obligatoire (DATABASE_URL requis)
  - DEVELOPMENT           : PostgreSQL recommandé, SQLite toléré avec warning

La variable DATABASE_URL doit être définie dans .env.
Format PostgreSQL : postgresql://user:password@host:port/dbname
"""

import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# ── Variables d'environnement ──────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL")
APP_ENV = os.getenv("APP_ENV", "development").lower()

_IS_PRODUCTION = APP_ENV in ("production", "staging", "prod", "stage")
_IS_SQLITE = False


def _fail_fast(msg: str) -> None:
    """Affiche une erreur critique et arrête le processus."""
    print(f"\n{'='*70}", file=sys.stderr)
    print(f"[DB] [ERR]  ERREUR CRITIQUE — {msg}", file=sys.stderr)
    print(f"{'='*70}\n", file=sys.stderr)
    sys.exit(1)


# ── Construction de l'engine ──────────────────────────────────────────────────
if DATABASE_URL:
    # ── PostgreSQL ─────────────────────────────────────────────────────────
    # Compatibilité Railway/Render : postgres:// → postgresql://
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

    if not DATABASE_URL.startswith("postgresql"):
        _fail_fast(
            "DATABASE_URL ne pointe pas vers PostgreSQL.\n"
            "  Valeur reçue : " + DATABASE_URL[:40] + "...\n"
            "  Format attendu : postgresql://user:password@host:port/dbname"
        )

    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,       # Vérifie la connexion avant chaque utilisation
        pool_size=10,             # Connexions persistantes en pool
        max_overflow=20,          # Connexions supplémentaires autorisées
        pool_timeout=30,          # Timeout avant erreur (secondes)
        pool_recycle=1800,        # Recycler les connexions après 30 min
    )
    print(f"[DB] [OK]  PostgreSQL connecté : {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else DATABASE_URL}")

else:
    # ── Pas de DATABASE_URL ───────────────────────────────────────────────
    if _IS_PRODUCTION:
        _fail_fast(
            "DATABASE_URL non défini en environnement de production.\n"
            "  PostgreSQL est obligatoire pour APP_ENV=production/staging.\n"
            "  Définissez DATABASE_URL dans votre fichier .env ou les variables d'environnement."
        )

    # ── Fallback SQLite (développement uniquement) ────────────────────────
    _IS_SQLITE = True
    _sqlite_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")

    print("\n" + "="*70, file=sys.stderr)
    print("[DB] [WARN]  ATTENTION — SQLite utilisé en mode développement.", file=sys.stderr)
    print(f"[DB] [WARN]  Fichier : {_sqlite_path}", file=sys.stderr)
    print("[DB] [WARN]  SQLite est INCOMPATIBLE avec la production :", file=sys.stderr)
    print("[DB] [WARN]    - Pas de concurrence réelle (verrous fichier)", file=sys.stderr)
    print("[DB] [WARN]    - Comportement différent pour JSON, FK, ALTER TABLE", file=sys.stderr)
    print("[DB] [WARN]  Définissez DATABASE_URL pour utiliser PostgreSQL.", file=sys.stderr)
    print("="*70 + "\n", file=sys.stderr)

    engine = create_engine(
        f"sqlite:///{_sqlite_path}",
        connect_args={"check_same_thread": False},
    )


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# ── Dependency FastAPI ─────────────────────────────────────────────────────────
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

