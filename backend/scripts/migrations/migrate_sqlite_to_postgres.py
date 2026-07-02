"""
migrate_sqlite_to_postgres.py
==============================
Script de migration des donnees de SQLite vers PostgreSQL.
Copie toutes les tables existantes vers la nouvelle base PostgreSQL.

Usage :
    cd backend
    python -X utf8 migrate_sqlite_to_postgres.py

Prerequis :
    - PostgreSQL installe et running
    - psycopg2-binary installe (pip install psycopg2-binary)
    - La base 'ecorewind' creee dans PostgreSQL
"""

import os
import sys
import sqlite3
import io
import psycopg2

# Force UTF-8 output sur Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Charger le .env manuellement
ENV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env')
DATABASE_URL = "postgresql://postgres@localhost:5432/ecorewind"

if os.path.exists(ENV_PATH):
    with open(ENV_PATH, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('DATABASE_URL=') and 'postgresql' in line:
                DATABASE_URL = line.split('=', 1)[1].strip()
                break

SQLITE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sql_app.db')

print(f"[INFO] URL PostgreSQL : {DATABASE_URL}")
print(f"[INFO] Source SQLite  : {SQLITE_PATH}")
print()

# Tables a migrer dans l'ordre (respecter les FK)
TABLES_ORDER = [
    "users",
    "posts",
    "saved_posts",
    "likes",
    "comments",
    "otp_codes",
    "notifications",
    "collection_points",
    "testimonials",
    "center_proposals",
    "video_categories",
    "educator_videos",
    "quizzes",
    "quiz_submissions",
]

# Colonnes de type BOOLEAN dans chaque table (SQLite les stocke en int 0/1)
BOOLEAN_COLS = {
    "users": ["is_active", "is_verified"],
    "posts": ["is_approved", "is_rejected", "needs_admin_review"],
    "collection_points": ["is_active"],
    "educator_videos": ["is_active", "is_published"],
    "quizzes": ["is_active"],
}


def convert_row(table: str, cols: list, row: tuple) -> tuple:
    """Convertit les valeurs SQLite (int booleans) vers les types PostgreSQL."""
    bool_cols = BOOLEAN_COLS.get(table, [])
    new_row = []
    for col, val in zip(cols, row):
        if col in bool_cols and val is not None:
            new_row.append(bool(val))  # 0 -> False, 1 -> True
        else:
            new_row.append(val)
    return tuple(new_row)


def get_pg_boolean_cols(pg_cur, table: str) -> set:
    """Recupere dynamiquement toutes les colonnes BOOLEAN d'une table PostgreSQL."""
    pg_cur.execute("""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = %s 
          AND table_schema = 'public' 
          AND data_type = 'boolean'
    """, (table,))
    return {row[0] for row in pg_cur.fetchall()}


def migrate_table(sq_cur, pg: psycopg2.extensions.connection, table: str, bool_cols: set) -> tuple:
    """Migre une table SQLite vers PostgreSQL. Retourne (migrees, doublons, erreurs)."""
    # Lire depuis SQLite
    try:
        sq_cur.execute(f"SELECT * FROM {table}")
        rows = sq_cur.fetchall()
    except sqlite3.OperationalError as e:
        if "no such table" in str(e):
            print(f"  [SKIP] {table} : table inexistante dans SQLite")
            return 0, 0, 0
        print(f"  [ERR]  {table} : erreur SQLite — {e}")
        return 0, 0, 0

    if not rows:
        print(f"  [VIDE] {table} : 0 ligne dans SQLite")
        return 0, 0, 0

    cols = list(rows[0].keys())
    col_quoted = ", ".join([f'"{c}"' for c in cols])
    placeholders = ", ".join(["%s"] * len(cols))
    sql_insert = f'INSERT INTO "{table}" ({col_quoted}) VALUES ({placeholders}) ON CONFLICT DO NOTHING'

    migrated = skipped = errors = 0

    for row_raw in rows:
        values_raw = tuple(row_raw[c] for c in cols)
        # Convertir les booléens
        values = []
        for col, val in zip(cols, values_raw):
            if col in bool_cols and val is not None:
                values.append(bool(val))
            else:
                values.append(val)
        values = tuple(values)

        # Essayer l'insertion
        pg_cur = pg.cursor()
        try:
            pg_cur.execute(sql_insert, values)
            if pg_cur.rowcount == 0:
                skipped += 1
            else:
                migrated += 1
            pg.commit()
        except Exception as e:
            pg.rollback()
            errors += 1
            if errors <= 3:  # Afficher les 3 premieres erreurs seulement
                print(f"    [WARN] Ligne ignoree ({table}): {str(e)[:80]}")

    return migrated, skipped, errors


def main():
    print("=" * 60)
    print("  EcoRewind -- Migration SQLite -> PostgreSQL")
    print("=" * 60)

    if not os.path.exists(SQLITE_PATH):
        print(f"[ERREUR] SQLite introuvable : {SQLITE_PATH}")
        sys.exit(1)

    sq = sqlite3.connect(SQLITE_PATH)
    sq.row_factory = sqlite3.Row
    sq_cur = sq.cursor()

    try:
        pg = psycopg2.connect(DATABASE_URL)
        pg.autocommit = False
        print("[OK] Connexion PostgreSQL etablie\n")
    except Exception as e:
        print(f"[ERREUR] Connexion PostgreSQL : {e}")
        sys.exit(1)

    # --- Creer les tables via SQLAlchemy ---
    print("[...] Creation / verification des tables PostgreSQL...")
    try:
        # Patcher temporairement les variables d'env pour SQLAlchemy
        os.environ['DATABASE_URL'] = DATABASE_URL
        
        from database import engine, Base
        import db_models  # noqa
        Base.metadata.create_all(bind=engine)
        engine.dispose()
        print("[OK] Tables OK\n")
    except Exception as e:
        print(f"[ERR] Creation tables : {e}\n")

    # Recuperer les colonnes boolean de chaque table dynamiquement
    pg_check = psycopg2.connect(DATABASE_URL)
    pg_check.autocommit = True
    pg_check_cur = pg_check.cursor()

    # --- Migration table par table ---
    print("[...] Migration des donnees...\n")
    total_migrated = 0
    total_skipped = 0
    total_errors = 0

    for table in TABLES_ORDER:
        # Detecter automatiquement les colonnes boolean
        bool_cols = get_pg_boolean_cols(pg_check_cur, table)

        migrated, skipped, errors = migrate_table(sq_cur, pg, table, bool_cols)
        total_migrated += migrated
        total_skipped += skipped
        total_errors += errors

        if migrated > 0 or skipped > 0:
            parts = [f"{migrated} migrees"]
            if skipped > 0:
                parts.append(f"{skipped} doublons")
            if errors > 0:
                parts.append(f"{errors} erreurs")
            print(f"  [OK]   {table} : {', '.join(parts)}")

    pg_check.close()

    # --- Reset des sequences auto-increment ---
    print("\n[...] Remise a jour des sequences (auto-increment)...")
    pg_seq = psycopg2.connect(DATABASE_URL)
    pg_seq.autocommit = False
    seq_cur = pg_seq.cursor()
    seq_ok = 0

    for table in TABLES_ORDER + ["bin_scans"]:
        try:
            seq_cur.execute(f"""
                SELECT setval(
                    pg_get_serial_sequence('{table}', 'id'),
                    COALESCE((SELECT MAX(id) FROM {table}), 1)
                );
            """)
            seq_ok += 1
        except Exception:
            pg_seq.rollback()
            seq_cur = pg_seq.cursor()

    try:
        pg_seq.commit()
        print(f"[OK] {seq_ok} sequences mises a jour")
    except Exception:
        pg_seq.rollback()
    pg_seq.close()

    # --- Rapport final ---
    sq.close()
    pg.close()

    print()
    print("=" * 60)
    print(f"  [OK] Migration terminee !")
    print(f"  Lignes migrees  : {total_migrated}")
    print(f"  Doublons ignores: {total_skipped}")
    if total_errors > 0:
        print(f"  Erreurs         : {total_errors}")
    print("=" * 60)
    print()
    print("[NEXT] Verifie les donnees :")
    print("   python -X utf8 check_pg.py")
    print()
    print("[NEXT] Puis demarre le backend :")
    print("   uvicorn main:app --reload")


if __name__ == "__main__":
    main()
