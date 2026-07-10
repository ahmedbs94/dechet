import os
import sys

# Add backend to path
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, BACKEND_DIR)

from dotenv import load_dotenv
load_dotenv(os.path.join(BACKEND_DIR, ".env"))

from database import engine
from sqlalchemy import text

def migrate():
    print(f"[DB] Connecté à l'engine...")
    with engine.begin() as conn:
        print("Exécution des requêtes DDL...")
        # 1. Rendre zone_id et collector_id NULLABLE
        conn.execute(text("ALTER TABLE collector_zone_assignments ALTER COLUMN zone_id DROP NOT NULL"))
        conn.execute(text("ALTER TABLE collector_zone_assignments ALTER COLUMN collector_id DROP NOT NULL"))
        print("zone_id et collector_id rendus optionnels")

        # 2. Ajouter collection_point_id
        conn.execute(text("""
            ALTER TABLE collector_zone_assignments 
            ADD COLUMN IF NOT EXISTS collection_point_id INTEGER 
            REFERENCES collection_points(id) ON DELETE CASCADE
        """))
        print("colonne collection_point_id ajoutee")

        # 3. Ajouter group_id
        conn.execute(text("""
            ALTER TABLE collector_zone_assignments 
            ADD COLUMN IF NOT EXISTS group_id INTEGER 
            REFERENCES custom_actor_groups(id) ON DELETE CASCADE
        """))
        print("colonne group_id ajoutee")
        
        print("[OK] Migration de la structure collector_zone_assignments terminée avec succès.")

if __name__ == "__main__":
    migrate()
