import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import psycopg2, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
conn = psycopg2.connect("postgresql://postgres@localhost:5432/ecorewind")
cur = conn.cursor()

print("=== Centres Nabeul / Marbella ===")
cur.execute("SELECT id, name, status, address FROM collection_points WHERE address ILIKE '%nabeul%' OR address ILIKE '%marbella%' OR name ILIKE '%nabeul%'")
for r in cur.fetchall():
    print(r)

print("\n=== Tous les statuts ===")
cur.execute("SELECT status, COUNT(*) FROM collection_points GROUP BY status")
for r in cur.fetchall():
    print(r)

print("\n=== Backend analytics: by-status query test ===")
cur.execute("""
    SELECT status, COUNT(*) as count
    FROM collection_points
    WHERE address ILIKE '%nabeul%' OR name ILIKE '%nabeul%'
    GROUP BY status
""")
for r in cur.fetchall():
    print(r)

cur.close()
conn.close()
