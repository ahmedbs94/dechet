"""
alembic/env.py — Configuration de l'environnement Alembic pour EcoRewind
=========================================================================
- Lit DATABASE_URL depuis .env (SQLite fallback si absent)
- Importe tous les modèles SQLAlchemy via db_models (nécessaire pour --autogenerate)
- Supporte les migrations online (PostgreSQL) et offline (génération SQL pure)
- Gestion du dialecte SQLite : certaines opérations DDL (ALTER COLUMN)
  ne sont pas supportées → batch mode activé automatiquement.
"""

import os
import sys
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

# ── Ajouter le répertoire backend/ au PYTHONPATH ─────────────────────────────
# Nécessaire pour que `from database import Base` fonctionne depuis alembic/
_backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

# ── Charger les variables d'environnement depuis .env ────────────────────────
from dotenv import load_dotenv
load_dotenv(os.path.join(_backend_dir, ".env"))

# ── Importer Base + tous les modèles (pour que --autogenerate les détecte) ───
from database import Base  # noqa: E402

# Import de tous les modèles enregistrés sur Base.metadata
import db_models  # noqa: F401, E402 — side-effect import (enregistre les tables)
from app.intercommunality import zone_models  # noqa: F401, E402 — tables F5 zones/assignments
from app.intercommunality import models as intercommunality_models  # noqa: F401, E402


# ── Résoudre l'URL de la base de données ────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL", "")

if DATABASE_URL:
    # Compatibilité Railway/Render : postgres:// → postgresql://
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)
else:
    # Fallback SQLite local
    _sqlite_path = os.path.join(_backend_dir, "sql_app.db")
    DATABASE_URL = f"sqlite:///{_sqlite_path}"
    print(f"[Alembic] WARN: DATABASE_URL non defini — SQLite en fallback : {_sqlite_path}")

# ── Configuration Alembic ────────────────────────────────────────────────────
config = context.config
config.set_main_option("sqlalchemy.url", DATABASE_URL)

# Logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Metadata cible pour --autogenerate
target_metadata = Base.metadata

# ── Détection du dialecte SQLite ────────────────────────────────────────────
_IS_SQLITE = DATABASE_URL.startswith("sqlite")


def run_migrations_offline() -> None:
    """
    Mode offline : génère du SQL pur sans connexion DB.
    Utile pour révision manuelle ou environnements restreints.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        # SQLite : batch mode pour ALTER TABLE
        render_as_batch=_IS_SQLITE,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """
    Mode online : connexion directe à la DB, migration immédiate.
    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            # SQLite : batch mode obligatoire pour ALTER TABLE / DROP COLUMN
            render_as_batch=_IS_SQLITE,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


# ── Point d'entrée ───────────────────────────────────────────────────────────
if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
