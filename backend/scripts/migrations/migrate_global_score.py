"""
Migration: Ajouter la colonne global_score a la table users
=============================================================
Usage: python migrate_global_score.py
"""
import sys, os
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from database import engine
from sqlalchemy import inspect, text

inspector = inspect(engine)

# Vérifier si la colonne existe déjà
columns = [c["name"] for c in inspector.get_columns("users")]

if "global_score" in columns:
    print("[OK] La colonne 'global_score' existe deja dans la table 'users'.")
else:
    with engine.connect() as conn:
        conn.execute(text("ALTER TABLE users ADD COLUMN global_score FLOAT DEFAULT 0.0"))
        conn.commit()
    print("[OK] Colonne 'global_score' ajoutee a la table 'users' avec succes.")

# Verification
inspector = inspect(engine)
columns = [c["name"] for c in inspector.get_columns("users")]
print(f"  [users] colonnes: {', '.join(columns)}")
