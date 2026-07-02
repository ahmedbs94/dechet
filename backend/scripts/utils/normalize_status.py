import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import psycopg2, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

conn = psycopg2.connect("postgresql://postgres@localhost:5432/ecorewind")
cur = conn.cursor()

# Normaliser tous les statuts en minuscule canonical
updates = [
    ("disponible", ["Disponible", "DISPONIBLE", "Available"]),
    ("saturé",     ["Saturé", "SATURÉ", "Sature", "saturé", "sature"]),
    ("maintenance", ["Maintenance", "MAINTENANCE"]),
]
total = 0
for target, variants in updates:
    for v in variants:
        cur.execute("UPDATE collection_points SET status = %s WHERE status = %s RETURNING id", (target, v))
        rows = cur.fetchall()
        if rows:
            print(f"  {v!r} → {target!r} : {len(rows)} centres mis à jour ({[r[0] for r in rows]})")
            total += len(rows)

conn.commit()
print(f"\nTotal mis à jour : {total}")

cur.execute("SELECT status, COUNT(*) FROM collection_points GROUP BY status ORDER BY status")
print("\nStatuts après normalisation:")
for r in cur.fetchall():
    print(f"  {r[0]!r}: {r[1]}")

cur.close()
conn.close()
