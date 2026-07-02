import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
seed_smart_bins.py
==================
Crée des poubelles intelligentes de demonstration dans la base SQLite.
Chaque poubelle a un bin_code unique, un type de dechet, et est associee
(si possible) au premier point de collecte existant.

Usage :
    python seed_smart_bins.py
"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")

DEMO_BINS = [
    ("BIN-PLASTIQUE-001", "plastique",    50.0,  "Entree principale"),
    ("BIN-VERRE-001",     "verre",        80.0,  "Cote gauche"),
    ("BIN-PAPIER-001",    "papier",       40.0,  "Couloir A"),
    ("BIN-CARTON-001",    "carton",       60.0,  "Zone decharge"),
    ("BIN-METAL-001",     "metal",        30.0,  "Atelier"),
    ("BIN-ORGANIQUE-001", "organique",    20.0,  "Cantine"),
    ("BIN-ELEC-001",      "electronique", 15.0,  "Reception"),
    ("BIN-TEXTILE-001",   "textile",      25.0,  "Vestiaires"),
    ("BIN-GENERAL-001",   "general",      100.0, "Parking"),
]

def seed():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Recuperer le premier point de collecte (pour rattacher les bacs)
    cursor.execute("SELECT id FROM collection_points LIMIT 1")
    row = cursor.fetchone()
    cp_id = row[0] if row else None
    print(f"[INFO] Point de collecte reference : #{cp_id}")

    created = 0
    skipped = 0
    for bin_code, bin_type, capacity_kg, location_note in DEMO_BINS:
        cursor.execute("SELECT id FROM smart_bins WHERE bin_code = ?", (bin_code,))
        if cursor.fetchone():
            print(f"  [SKIP] {bin_code} deja present")
            skipped += 1
            continue
        cursor.execute("""
            INSERT INTO smart_bins
                (bin_code, collection_point_id, bin_type, capacity_kg, status, location_note)
            VALUES (?, ?, ?, ?, 'active', ?)
        """, (bin_code, cp_id, bin_type, capacity_kg, location_note))
        print(f"  [ADD]  {bin_code:25s} | {bin_type:12s} | {capacity_kg:5.1f} kg")
        created += 1

    conn.commit()
    conn.close()
    print(f"\n[OK] {created} poubelle(s) creee(s), {skipped} ignoree(s) (deja existante).")
    print("[TIP] Testez avec : POST /qr/scan-bin { bin_code: 'BIN-PLASTIQUE-001', qr_code: '<votre_qr>' }")

if __name__ == "__main__":
    seed()
