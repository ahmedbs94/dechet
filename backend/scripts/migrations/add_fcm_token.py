"""
Migration PostgreSQL : Ajout de la colonne fcm_token à la table users
Exécuter avec : python add_fcm_token.py
"""
import os
import sys

# Charger les variables d'environnement depuis .env
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

try:
    from dotenv import load_dotenv
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    load_dotenv(env_path)
    print(f"[ENV] Fichier .env charge : {env_path}")
except ImportError:
    print("[ENV] python-dotenv non disponible, variables d'env manuelles...")

from database import engine
from sqlalchemy import text


def migrate():
    db_url = os.getenv("DATABASE_URL", "")
    print(f"[DB] Connexion : {db_url.split('@')[-1] if '@' in db_url else db_url or 'SQLite fallback'}")

    with engine.connect() as conn:
        # Verifier si la colonne existe deja
        try:
            conn.execute(text("SELECT fcm_token FROM users LIMIT 1"))
            print("[OK] La colonne fcm_token existe deja - aucune action requise.")
        except Exception:
            # La colonne n'existe pas -> on l'ajoute
            print("[INFO] Ajout de la colonne fcm_token...")
            conn.execute(text("ALTER TABLE users ADD COLUMN fcm_token VARCHAR"))
            conn.commit()
            print("[OK] Colonne fcm_token ajoutee avec succes a la table users.")


if __name__ == "__main__":
    migrate()
