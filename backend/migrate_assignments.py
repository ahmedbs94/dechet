"""
Migration complète :
1. Crée toutes les tables manquantes (create_all)
2. Recrée collector_zone_assignments avec zone_id nullable + nouvelles colonnes
"""
import sys, os
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, '.')

from database import engine, Base
from sqlalchemy import text

# Importer tous les modèles pour que Base.metadata les connaisse
import db_models  # noqa
try:
    from app.intercommunality.zone_models import CollectorZone, CollectorZoneAssignment
    from app.intercommunality.models import LocalInstruction, CustomActorGroup
except Exception as e:
    print(f"Import models warning: {e}")

# 1. Créer toutes les tables qui n'existent pas encore
Base.metadata.create_all(bind=engine)
print("create_all() done")

with engine.connect() as conn:
    # Vérifier si la table existe maintenant
    r = conn.execute(text("SELECT name FROM sqlite_master WHERE type='table' AND name='collector_zone_assignments'"))
    exists = r.fetchone()
    print(f"Table collector_zone_assignments exists: {bool(exists)}")

    if exists:
        # Vérifier les colonnes actuelles
        r2 = conn.execute(text("PRAGMA table_info(collector_zone_assignments)"))
        current_cols = {row[1] for row in r2.fetchall()}
        print(f"Current columns: {sorted(current_cols)}")

        needs_migration = 'collection_point_ids' not in current_cols or 'target_label' not in current_cols

        if needs_migration:
            print("Migrating table...")
            # Recréer la table avec zone_id nullable + nouvelles colonnes
            conn.execute(text(
                "CREATE TABLE IF NOT EXISTS czassign_new ("
                "id INTEGER PRIMARY KEY, "
                "zone_id INTEGER REFERENCES collector_zones(id) ON DELETE CASCADE, "
                "collector_id INTEGER NOT NULL REFERENCES users(id), "
                "assigned_by INTEGER NOT NULL REFERENCES users(id), "
                "mission_message TEXT, "
                "priority VARCHAR DEFAULT 'normal', "
                "status VARCHAR DEFAULT 'pending', "
                "due_date DATETIME, "
                "assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP, "
                "completed_at DATETIME, "
                "collector_notes TEXT, "
                "collection_point_ids TEXT, "
                "target_label VARCHAR(200)"
                ")"
            ))
            # Copier les données existantes
            common_cols = "id,zone_id,collector_id,assigned_by,mission_message,priority,status,due_date,assigned_at,completed_at,collector_notes"
            conn.execute(text(
                f"INSERT INTO czassign_new ({common_cols}) "
                f"SELECT {common_cols} FROM collector_zone_assignments"
            ))
            conn.execute(text("DROP TABLE collector_zone_assignments"))
            conn.execute(text("ALTER TABLE czassign_new RENAME TO collector_zone_assignments"))
            print("Table recreated with new columns!")
        else:
            print("Table already has new columns - no migration needed")

    conn.commit()
    r3 = conn.execute(text("PRAGMA table_info(collector_zone_assignments)"))
    print("Final columns:", [row[1] for row in r3.fetchall()])
