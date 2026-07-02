import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import psycopg2

conn = psycopg2.connect("postgresql://postgres@localhost:5432/ecorewind")
cur = conn.cursor()
cur.execute("SELECT id, name, address FROM collection_points ORDER BY id")
rows = cur.fetchall()
print(f"Total: {len(rows)} centres\n")
for r in rows:
    addr = (r[2] or 'NULL')[:70]
    print(f"[{r[0]}] {r[1]}")
    print(f"     Adresse: {addr}")
cur.close()
conn.close()
