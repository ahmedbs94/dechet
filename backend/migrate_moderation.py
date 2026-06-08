"""
migrate_moderation.py
=====================
Applique toutes les colonnes de modération IA sur la table `posts` :

  status                    TEXT NOT NULL DEFAULT 'pending_ai'
  moderation_score          REAL NOT NULL DEFAULT 0.0
  moderation_reason         TEXT
  moderation_details        TEXT
  moderated_at              TEXT   ← horodatage ISO de la décision IA
  moderation_model_version  TEXT   ← ex: "RuleBased|EcoCNN_v1"

Idempotent : chaque colonne est ignorée si elle existe déjà.
"""

import sqlite3

DB_PATH = "sql_app.db"

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# ── État avant migration ───────────────────────────────────────────────────────
cursor.execute("PRAGMA table_info(posts)")
existing_cols = [row[1] for row in cursor.fetchall()]
print(f"Colonnes actuelles posts : {existing_cols}\n")

# ── Définition des colonnes à ajouter ─────────────────────────────────────────
migrations = [
    # (nom_colonne, définition_SQLite)
    ("status",                   "TEXT NOT NULL DEFAULT 'pending_ai'"),
    ("moderation_score",         "REAL NOT NULL DEFAULT 0.0"),
    ("moderation_reason",        "TEXT"),
    ("moderation_details",       "TEXT"),
    ("moderated_at",             "TEXT"),          # Horodatage ISO de la décision IA
    ("moderation_model_version", "TEXT"),          # Ex: "RuleBased|EcoCNN_v1"
]

for col_name, col_def in migrations:
    if col_name not in existing_cols:
        cursor.execute(f"ALTER TABLE posts ADD COLUMN {col_name} {col_def}")
        print(f"  [+] Colonne ajoutée   : {col_name}")
    else:
        print(f"  [=] Colonne existante : {col_name} (ignorée)")

conn.commit()

# ── Normalisation des anciens posts sans statut IA ────────────────────────────
# Les posts créés avant cette migration ont status='published' (ancien défaut).
# On les laisse tels quels (ils ont été publiés manuellement ou par l'ancienne
# logique). Seuls les nouveaux posts utilisent le flux pending_ai → published.

# ── Vérification finale ───────────────────────────────────────────────────────
cursor.execute("PRAGMA table_info(posts)")
final_cols = [(row[1], row[2]) for row in cursor.fetchall()]
print(f"\nposts APRÈS migration :")
for name, typ in final_cols:
    marker = " [NEW]" if name in ("moderated_at", "moderation_model_version") else ""
    print(f"  {name:30s} {typ}{marker}")

conn.close()
print("\nMigration moderation terminee [OK]")
