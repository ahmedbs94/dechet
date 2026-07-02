import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
migrate_mfa.py — Ajoute la colonne mfa_enabled a la table users.
Executer une seule fois : python migrate_mfa.py
"""
import os
import sys

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres@localhost:5432/ecorewind"
)

def migrate_postgres():
    try:
        import psycopg2
        conn = psycopg2.connect(DATABASE_URL)
        conn.autocommit = True
        c = conn.cursor()

        c.execute("""
            ALTER TABLE users
            ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE;
        """)
        print("[OK] [PostgreSQL] Colonne 'mfa_enabled' ajoutee (ou deja presente).")

        c.execute("""
            SELECT column_name, data_type, column_default
            FROM information_schema.columns
            WHERE table_name = 'users' AND column_name = 'mfa_enabled';
        """)
        row = c.fetchone()
        if row:
            print(f"   -> colonne={row[0]}, type={row[1]}, defaut={row[2]}")

        conn.close()
        return True
    except Exception as e:
        print(f"[WARN] PostgreSQL indisponible : {e}")
        return False


def migrate_sqlite():
    import sqlite3
    db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("PRAGMA table_info(users)")
    columns = [col[1] for col in cursor.fetchall()]

    if "mfa_enabled" not in columns:
        cursor.execute("ALTER TABLE users ADD COLUMN mfa_enabled BOOLEAN NOT NULL DEFAULT 0")
        conn.commit()
        print(f"[OK] [SQLite] Colonne 'mfa_enabled' ajoutee dans {db_path}")
    else:
        print("[INFO] [SQLite] Colonne 'mfa_enabled' deja presente.")

    conn.close()


if __name__ == "__main__":
    print("=" * 60)
    print("  Migration : Authentification Forte (mfa_enabled)")
    print("=" * 60)

    if not migrate_postgres():
        migrate_sqlite()

    print("\nMigration terminee !")
