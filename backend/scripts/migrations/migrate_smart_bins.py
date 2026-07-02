import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
migrate_smart_bins.py
=====================
Migration : Crée la table smart_bins et ajoute smart_bin_id à bin_scans.

Exécution :
    python migrate_smart_bins.py

Ce script est idempotent : il peut être relancé sans risque si les colonnes
existent déjà.
"""

import sqlite3
import os
import sys

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")


def migrate():
    print(f"[DB] Base de donnees : {DB_PATH}")
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = OFF")   # désactivé le temps de la migration
    cursor = conn.cursor()

    # ────────────────────────────────────────────────────────────────────────
    # 1. Créer la table smart_bins (si elle n'existe pas)
    # ────────────────────────────────────────────────────────────────────────
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS smart_bins (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            bin_code            TEXT    NOT NULL UNIQUE,
            collection_point_id INTEGER REFERENCES collection_points(id),
            bin_type            TEXT    NOT NULL DEFAULT 'general',
            capacity_kg         REAL,
            status              TEXT    NOT NULL DEFAULT 'active',
            location_note       TEXT,
            created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS ix_smart_bins_bin_code ON smart_bins(bin_code)")
    cursor.execute("CREATE INDEX IF NOT EXISTS ix_smart_bins_status   ON smart_bins(status)")
    print("[OK] Table smart_bins creee (ou deja existante).")

    # ────────────────────────────────────────────────────────────────────────
    # 2. Ajouter smart_bin_id à bin_scans (si absent)
    # ────────────────────────────────────────────────────────────────────────
    cursor.execute("PRAGMA table_info(bin_scans)")
    existing_cols = {row[1] for row in cursor.fetchall()}

    if "smart_bin_id" not in existing_cols:
        cursor.execute(
            "ALTER TABLE bin_scans ADD COLUMN smart_bin_id INTEGER REFERENCES smart_bins(id)"
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS ix_bin_scans_smart_bin_id ON bin_scans(smart_bin_id)"
        )
        print("[OK] Colonne smart_bin_id ajoutee a bin_scans.")
    else:
        print("[--] Colonne smart_bin_id deja presente dans bin_scans.")

    # ────────────────────────────────────────────────────────────────────────
    # 3. Rétro-relier les scans existants aux poubelles via bin_id → bin_code
    #    (utile si vous avez déjà des bin_scans avec bin_id textuel)
    # ────────────────────────────────────────────────────────────────────────
    cursor.execute("""
        UPDATE bin_scans
        SET smart_bin_id = (
            SELECT id FROM smart_bins
            WHERE smart_bins.bin_code = bin_scans.bin_id
        )
        WHERE smart_bin_id IS NULL AND bin_id IS NOT NULL
    """)
    linked = cursor.rowcount
    if linked:
        print(f"[LINK] {linked} scan(s) retro-lies via bin_id -> smart_bins.bin_code.")

    conn.commit()

    # ────────────────────────────────────────────────────────────────────────
    # 4. Résumé
    # ────────────────────────────────────────────────────────────────────────
    print("\n[INFO] Resume apres migration :")
    print("-" * 50)

    cursor.execute("SELECT COUNT(*) FROM smart_bins")
    nb_bins = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM smart_bins WHERE status = 'active'")
    nb_active = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM bin_scans")
    nb_scans = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM bin_scans WHERE smart_bin_id IS NOT NULL")
    nb_linked = cursor.fetchone()[0]

    print(f"   smart_bins  : {nb_bins} total, {nb_active} active(s)")
    print(f"   bin_scans   : {nb_scans} total, {nb_linked} lies a un smart_bin")

    if nb_bins > 0:
        print("\n   Detail smart_bins :")
        cursor.execute(
            "SELECT id, bin_code, bin_type, status, collection_point_id FROM smart_bins ORDER BY id"
        )
        for row in cursor.fetchall():
            sid, code, btype, status, cp_id = row
            print(f"     #{sid:3d} | {code:30s} | {btype:12s} | {status:12s} | CP={cp_id}")

    conn.execute("PRAGMA foreign_keys = ON")
    conn.close()
    print("\n[OK] Migration smart_bins terminee avec succes.")


if __name__ == "__main__":
    if not os.path.exists(DB_PATH):
        print(f"[ERR] Base de donnees introuvable : {DB_PATH}")
        sys.exit(1)
    migrate()
