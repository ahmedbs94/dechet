import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
check_schema.py — Voir le schema reel des tables PostgreSQL
"""
import sys, io, psycopg2
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

PG_URL = "postgresql://postgres@localhost:5432/ecorewind"
pg = psycopg2.connect(PG_URL)
pg.autocommit = True
c = pg.cursor()

# Colonnes de la table users
c.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'users' AND table_schema = 'public'
    ORDER BY ordinal_position
""")
cols = c.fetchall()
print("=== Colonnes de la table 'users' dans PostgreSQL ===")
for col in cols:
    print(f"  {col[0]}: {col[1]}")

# Verifier les colonnes SQLite
print("\n=== Colonnes de la table 'users' dans SQLite ===")
import sqlite3
sq = sqlite3.connect("sql_app.db")
sq_c = sq.cursor()
sq_c.execute("PRAGMA table_info(users)")
for col in sq_c.fetchall():
    print(f"  {col[1]}: {col[2]}")

sq.close()
pg.close()
