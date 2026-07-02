import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
Script pour créer des poubelles de test dans PostgreSQL ET Firebase.
Exécution : python seed_poubelles.py
"""
import os, sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(BASE_DIR, ".env"))
except ImportError:
    pass

import app.users.models
import app.posts.models
import app.qr_bins.models
import app.collection_points.models

from database import SessionLocal
from app.qr_bins.models import SmartBin
from services.firebase_service import update_bin_status, _init_firebase

# Poubelles de test à créer
POUBELLES = [
    {"bin_code": "BIN-PLASTIQUE-001", "bin_type": "plastique",    "capacity_kg": 50.0,  "location_note": "Entree principale"},
    {"bin_code": "BIN-VERRE-001",     "bin_type": "verre",        "capacity_kg": 60.0,  "location_note": "Parking A"},
    {"bin_code": "BIN-PAPIER-001",    "bin_type": "papier",       "capacity_kg": 40.0,  "location_note": "Batiment B"},
    {"bin_code": "BIN-METAL-001",     "bin_type": "metal",        "capacity_kg": 80.0,  "location_note": "Zone industrielle"},
    {"bin_code": "BIN-ORGANIQUE-001", "bin_type": "organique",    "capacity_kg": 30.0,  "location_note": "Marche central"},
    {"bin_code": "BIN-GENERAL-001",   "bin_type": "general",      "capacity_kg": 100.0, "location_note": "Place publique"},
]

def main():
    print("=" * 55)
    print("  Seed Poubelles -- PostgreSQL + Firebase")
    print("=" * 55)

    _init_firebase()
    db = SessionLocal()
    created = 0
    skipped = 0

    try:
        for p in POUBELLES:
            existing = db.query(SmartBin).filter(SmartBin.bin_code == p["bin_code"]).first()
            if existing:
                print(f"[--] Deja existante : {p['bin_code']}")
                # Sync Firebase quand meme
                update_bin_status(p["bin_code"], poids=0.0, etat="vide")
                skipped += 1
                continue

            bin_obj = SmartBin(
                bin_code      = p["bin_code"],
                bin_type      = p["bin_type"],
                capacity_kg   = p["capacity_kg"],
                location_note = p["location_note"],
                status        = "active",
            )
            db.add(bin_obj)
            db.commit()
            db.refresh(bin_obj)

            # Sync Firebase /poubelles
            update_bin_status(p["bin_code"], poids=0.0, etat="vide")
            print(f"[OK] Creee : {p['bin_code']} ({p['bin_type']}, {p['capacity_kg']}kg)")
            created += 1

    finally:
        db.close()

    print("-" * 55)
    print(f"  {created} creee(s)  |  {skipped} deja existante(s)")
    print("  --> Firebase /poubelles mis a jour !")
    print("=" * 55)

if __name__ == "__main__":
    main()
