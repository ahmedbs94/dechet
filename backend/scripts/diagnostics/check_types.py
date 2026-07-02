import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import psycopg2, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

conn = psycopg2.connect("postgresql://postgres@localhost:5432/ecorewind")
cur = conn.cursor()
cur.execute("SELECT id, name, types FROM collection_points ORDER BY id")
rows = cur.fetchall()
print(f"Total: {len(rows)} centres\n")
for r in rows:
    types_val = r[2] or 'NULL'
    print(f"[{r[0]}] {r[1]} | types = '{str(types_val)[:80]}'")
cur.close()
conn.close()
