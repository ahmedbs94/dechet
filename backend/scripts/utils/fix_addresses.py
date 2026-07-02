import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import psycopg2
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

conn = psycopg2.connect("postgresql://postgres@localhost:5432/ecorewind")
cur = conn.cursor()

# Effacer les adresses arabes pour les 4 centres ajoutés manuellement
arabic_ids = [11, 12, 13, 14]
cur.execute(
    "UPDATE collection_points SET address = NULL WHERE id = ANY(%s) RETURNING id, name",
    (arabic_ids,)
)
updated = cur.fetchall()
conn.commit()

print("Adresses effacees:")
for r in updated:
    print(f"  [{r[0]}] {r[1]}")

print(f"\n{len(updated)} centre(s) mis a jour. Le backfill re-geocodera en francais.")
cur.close()
conn.close()
