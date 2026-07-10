import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
debug_migration.py — Debug insertion par insertion pour trouver le probleme
"""
import sys, io, psycopg2, sqlite3
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

PG_URL = "postgresql://postgres@localhost:5432/ecorewind"

pg = psycopg2.connect(PG_URL)
pg.autocommit = False
pg_c = pg.cursor()

sq = sqlite3.connect("sql_app.db")
sq.row_factory = sqlite3.Row
sq_c = sq.cursor()

# Test avec la table users - insérer ligne par ligne avec debug
sq_c.execute("SELECT * FROM users LIMIT 3")
rows = sq_c.fetchall()
cols = list(rows[0].keys())
print(f"Colonnes SQLite: {cols}")
print(f"Nombre de lignes test: {len(rows)}\n")

col_quoted = ", ".join([f'"{c}"' for c in cols])
placeholders = ", ".join(["%s"] * len(cols))
sql = f'INSERT INTO users ({col_quoted}) VALUES ({placeholders}) ON CONFLICT DO NOTHING'
print(f"SQL: {sql}\n")

for i, row in enumerate(rows):
    values = tuple(row[c] for c in cols)
    print(f"Row {i+1} values preview: id={values[0]}, email={values[1][:20]}...")
    try:
        pg_c.execute(sql, values)
        print(f"  -> execute OK (rowcount={pg_c.rowcount})")
    except Exception as e:
        print(f"  -> ERREUR: {e}")
        pg.rollback()
        pg_c = pg.cursor()

try:
    pg.commit()
    print("\n[OK] Commit reussi!")
except Exception as e:
    print(f"\n[ERR] Commit echoue: {e}")
    pg.rollback()

# Verifier
pg_c.execute("SELECT COUNT(*) FROM users")
print(f"\n[CHECK] users dans PostgreSQL: {pg_c.fetchone()[0]} lignes")

sq.close()
pg.close()
