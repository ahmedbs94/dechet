import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
check_pg2.py — Diagnostic complet de la base PostgreSQL
"""
import sys, io, psycopg2
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

PG_URL = "postgresql://postgres@localhost:5432/ecorewind"

pg = psycopg2.connect(PG_URL)
pg.autocommit = True
c = pg.cursor()

# Lister toutes les tables dans le schema public
c.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    ORDER BY table_name
""")
tables = [row[0] for row in c.fetchall()]

print(f"[OK] {len(tables)} tables trouvees dans la base 'ecorewind':\n")
total = 0
for t in tables:
    try:
        c.execute(f'SELECT COUNT(*) FROM "{t}"')
        n = c.fetchone()[0]
        total += n
        status = "OK " if n > 0 else "---"
        print(f"  [{status}] {t}: {n} lignes")
    except Exception as e:
        print(f"  [ERR] {t}: {e}")

print(f"\n  TOTAL: {total} lignes")

# Verifier les doublons dans users (si des lignes existent)
c.execute("SELECT id, username, email FROM users LIMIT 5")
rows = c.fetchall()
if rows:
    print("\n  Exemple utilisateurs:")
    for r in rows:
        print(f"    id={r[0]}, user={r[1]}, email={r[2]}")
else:
    print("\n  [ATTENTION] Table users vide!")
    
    # Checker si les donnees sont dans un autre schema
    c.execute("""
        SELECT schemaname, tablename 
        FROM pg_tables 
        WHERE schemaname != 'information_schema' AND schemaname != 'pg_catalog'
        ORDER BY schemaname, tablename
    """)
    schemas = c.fetchall()
    print("\n  Toutes les tables (tous schemas):")
    for s in schemas:
        print(f"    schema={s[0]}, table={s[1]}")

pg.close()
