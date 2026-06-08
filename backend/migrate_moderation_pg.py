"""
migrate_moderation_pg.py
========================
Migration PostgreSQL : ajoute les colonnes de moderation IA manquantes
sur la table `posts` en production (Railway / Render / Postgres local).

Colonnes cibles :
  status                    VARCHAR  DEFAULT 'pending_ai'  NOT NULL
  moderation_score          FLOAT    DEFAULT 0.0           NOT NULL
  moderation_reason         TEXT
  moderation_details        TEXT
  moderated_at              TIMESTAMP WITH TIME ZONE
  moderation_model_version  VARCHAR

Usage :
  python migrate_moderation_pg.py
  DATABASE_URL=postgresql://... python migrate_moderation_pg.py
"""

import os
import sys

try:
    import psycopg2
except ImportError:
    print("[ERREUR] psycopg2 non installe. Lancez : pip install psycopg2-binary")
    sys.exit(1)

# ── Connexion ─────────────────────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres@localhost:5432/ecorewind")
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

print(f"Connexion : {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else DATABASE_URL}\n")

try:
    conn   = psycopg2.connect(DATABASE_URL)
    cursor = conn.cursor()
    print("[OK] Connexion PostgreSQL etablie\n")
except Exception as e:
    print(f"[ERREUR] Impossible de se connecter : {e}")
    sys.exit(1)

# ── Colonnes actuelles ────────────────────────────────────────────────────────
cursor.execute("""
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = 'posts'
    ORDER BY ordinal_position
""")
existing_cols = {row[0] for row in cursor.fetchall()}
print(f"Colonnes actuelles ({len(existing_cols)}) : {sorted(existing_cols)}\n")

# ── Migrations ────────────────────────────────────────────────────────────────
migrations = [
    # (nom_colonne, type_postgresql, clause_DEFAULT)
    ("status",                   "VARCHAR",                   "DEFAULT 'pending_ai' NOT NULL"),
    ("moderation_score",         "FLOAT",                     "DEFAULT 0.0 NOT NULL"),
    ("moderation_reason",        "TEXT",                      ""),
    ("moderation_details",       "TEXT",                      ""),
    ("moderated_at",             "TIMESTAMP WITH TIME ZONE",  ""),   # horodatage decision IA
    ("moderation_model_version", "VARCHAR",                   ""),   # ex: "RuleBased|EcoCNN_v1"
]

added = []
skipped = []

for col_name, col_type, col_extra in migrations:
    if col_name not in existing_cols:
        sql = f"ALTER TABLE posts ADD COLUMN {col_name} {col_type} {col_extra}".strip()
        try:
            cursor.execute(sql)
            conn.commit()
            added.append(col_name)
            print(f"  [+] Colonne ajoutee : {col_name:30s} {col_type}")
        except Exception as e:
            conn.rollback()
            print(f"  [!] Erreur sur {col_name} : {e}")
    else:
        skipped.append(col_name)
        print(f"  [=] Colonne existante : {col_name} (ignoree)")

# ── Verification finale ───────────────────────────────────────────────────────
cursor.execute("""
    SELECT column_name, data_type, column_default, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'posts'
    ORDER BY ordinal_position
""")
final_cols = cursor.fetchall()

print(f"\nposts APRES migration ({len(final_cols)} colonnes) :")
moderation_cols = {"status", "moderation_score", "moderation_reason",
                   "moderation_details", "moderated_at", "moderation_model_version"}
for name, dtype, default, nullable in final_cols:
    tag = " [MOD]" if name in moderation_cols else ""
    print(f"  {name:30s} {dtype:25s} nullable={nullable}{tag}")

conn.close()

print(f"\nMigration terminee : {len(added)} ajoutee(s), {len(skipped)} ignoree(s)")
if added:
    print(f"  Nouvelles colonnes : {', '.join(added)}")
print("\n[OK] Migration PostgreSQL terminee avec succes")
