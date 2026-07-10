import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
migrate_collector_logs.py
=========================
Migration : Crée la table collector_logs dans la base de données.

Cette table enregistre chaque opération de vidage effectuée par un collecteur :
  - Qui a vidé (collector_id → FK users)
  - Quelle poubelle (smart_bin_id + bin_code)
  - Quel type de déchet (bin_type)
  - Quelle quantité (weight_before_kg = poids avant remise à zéro)
  - La notification intercommunalité a-t-elle été envoyée ? (notified)
  - Quand (collected_at)

Exécution :
    cd backend
    python migrate_collector_logs.py

Ce script est idempotent : relancer ne cause aucun doublon ni erreur.
"""

import os
import sys

# ── Résolution du dossier backend ──────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

# ── Chargement des variables d'environnement (.env) ─────────────────────────
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(BASE_DIR, ".env"))
except ImportError:
    pass

DATABASE_URL = os.getenv("DATABASE_URL", "")

# ── Détection du moteur : PostgreSQL ou SQLite ───────────────────────────────
USE_POSTGRES = DATABASE_URL.startswith("postgresql")


def migrate_postgres():
    """Migration via SQLAlchemy (PostgreSQL)."""
    print("[DB] Mode : PostgreSQL")
    from database import engine
    from app.base import Base

    # Importer tous les modèles pour résoudre les relations
    import app.users.models           # noqa
    import app.posts.models           # noqa
    import app.qr_bins.models         # noqa  ← contient CollectorLog
    import app.collection_points.models  # noqa
    import app.community.models       # noqa
    import app.notifications.models   # noqa
    import app.quiz.models            # noqa
    import app.education.models       # noqa
    import app.auth.models            # noqa

    # Créer uniquement les tables manquantes (create_all est idempotent)
    Base.metadata.create_all(bind=engine)
    print("[OK] Table collector_logs créée (ou déjà existante) via SQLAlchemy.")

    # Vérification
    from sqlalchemy import inspect
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    if "collector_logs" in tables:
        columns = {col["name"] for col in inspector.get_columns("collector_logs")}
        print(f"[OK] Colonnes : {sorted(columns)}")
    else:
        print("[ERR] La table collector_logs n'a pas été créée !")
        sys.exit(1)


def migrate_sqlite():
    """Migration directe SQLite (sans SQLAlchemy ORM)."""
    DB_PATH = os.path.join(BASE_DIR, "sql_app.db")
    if not os.path.exists(DB_PATH):
        print(f"[ERR] Base de données SQLite introuvable : {DB_PATH}")
        sys.exit(1)

    print(f"[DB] Mode : SQLite → {DB_PATH}")

    import sqlite3
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = OFF")
    cursor = conn.cursor()

    # ── 1. Créer la table collector_logs ────────────────────────────────────
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS collector_logs (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            collector_id     INTEGER NOT NULL REFERENCES users(id),
            smart_bin_id     INTEGER REFERENCES smart_bins(id),
            bin_code         TEXT    NOT NULL,
            bin_type         TEXT,
            weight_before_kg REAL    DEFAULT 0.0,
            notified         INTEGER DEFAULT 0,   -- 0=False, 1=True (SQLite booléen)
            collected_at     DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    print("[OK] Table collector_logs créée (ou déjà existante).")

    # ── 2. Créer les index ───────────────────────────────────────────────────
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS ix_collector_logs_collector_id  ON collector_logs(collector_id)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS ix_collector_logs_smart_bin_id  ON collector_logs(smart_bin_id)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS ix_collector_logs_bin_code      ON collector_logs(bin_code)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS ix_collector_logs_collected_at  ON collector_logs(collected_at)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS ix_collector_logs_notified      ON collector_logs(notified)"
    )
    print("[OK] Index créés.")

    conn.commit()

    # ── 3. Résumé ────────────────────────────────────────────────────────────
    cursor.execute("SELECT COUNT(*) FROM collector_logs")
    nb = cursor.fetchone()[0]

    cursor.execute("PRAGMA table_info(collector_logs)")
    cols = [row[1] for row in cursor.fetchall()]

    print("\n[INFO] Résumé après migration :")
    print("-" * 50)
    print(f"   collector_logs : {nb} enregistrement(s)")
    print(f"   Colonnes       : {cols}")

    conn.execute("PRAGMA foreign_keys = ON")
    conn.close()
    print("\n[OK] Migration collector_logs terminée avec succès.")


def main():
    print("=" * 60)
    print("  EcoRewind — Migration : collector_logs")
    print("=" * 60)

    if USE_POSTGRES:
        migrate_postgres()
    else:
        migrate_sqlite()

    print("=" * 60)


if __name__ == "__main__":
    main()
