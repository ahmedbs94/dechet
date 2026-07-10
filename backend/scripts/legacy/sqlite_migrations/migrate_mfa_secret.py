import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
migrate_mfa_secret.py — Ajoute la colonne mfa_secret a la table users.
Executer une seule fois : python migrate_mfa_secret.py
"""
import os
import sqlite3
from dotenv import load_dotenv

# Charger les variables d'environnement (.env)
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def migrate_postgresql():
    if not DATABASE_URL or not DATABASE_URL.startswith("postgres"):
        return False
    
    import psycopg2
    try:
        url = DATABASE_URL
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql://", 1)
        
        conn = psycopg2.connect(url)
        conn.autocommit = True
        cursor = conn.cursor()
        
        # Ajouter la colonne mfa_secret si elle n'existe pas
        cursor.execute("""
            ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_secret VARCHAR;
        """)
        print("[OK] [PostgreSQL] Colonne 'mfa_secret' ajoutee (ou deja presente).")
        
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"[WARN] PostgreSQL indisponible : {e}")
        return False


def migrate_sqlite():
    db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")
    if not os.path.exists(db_path):
        print(f"[INFO] SQLite db_path non trouve a {db_path}, pas de migration SQLite necessaire.")
        return
        
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("PRAGMA table_info(users)")
    columns = [col[1] for col in cursor.fetchall()]

    if "mfa_secret" not in columns:
        cursor.execute("ALTER TABLE users ADD COLUMN mfa_secret VARCHAR")
        conn.commit()
        print(f"[OK] [SQLite] Colonne 'mfa_secret' ajoutee dans {db_path}")
    else:
        print("[INFO] [SQLite] Colonne 'mfa_secret' deja presente.")

    conn.close()


if __name__ == "__main__":
    print("  Migration : Authentification Forte - Ajout de mfa_secret")
    pg_success = migrate_postgresql()
    migrate_sqlite()
    print("Migration terminee.")
