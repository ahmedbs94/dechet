"""
initial_bin_sync.py
--------------------
Synchronisation initiale de toutes les poubelles PostgreSQL -> Firebase.
Ajoute le champ status_sql a chaque noeud Firebase pour la coherence.
"""
import sys, io, os
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from database import SessionLocal
import db_models as m
from services.firebase_service import _init_firebase, get_bin_status
from firebase_admin import db as rtdb
from datetime import datetime, timezone

db = SessionLocal()
_init_firebase()

STATUS_TO_ETAT = {
    "active":      None,           # calcule depuis poids
    "full":        "plein",
    "maintenance": "en_maintenance",
    "inactive":    "en_maintenance",
}

bins = db.query(m.SmartBin).order_by(m.SmartBin.id).all()
print("=== SYNC PostgreSQL -> Firebase ===\n")

for b in bins:
    # Lire poids actuel Firebase
    current = get_bin_status(b.bin_code) or {}
    poids = float(current.get("poids", 0.0))

    etat = STATUS_TO_ETAT.get(b.status)
    if etat is None:
        cap = b.capacity_kg or 100.0
        ratio = poids / cap if cap > 0 else 0
        if ratio >= 0.9:
            etat = "plein"
        elif ratio >= 0.5:
            etat = "mi-plein"
        else:
            etat = "vide"

    rtdb.reference("poubelles/" + b.bin_code).update({
        "poids":                poids,
        "etat":                 etat,
        "bin_type":             b.bin_type,
        "capacite_kg":          b.capacity_kg,
        "status_sql":           b.status,
        "derniere_mise_a_jour": datetime.now(timezone.utc).isoformat(),
    })

    print("  [OK] " + b.bin_code +
          " | status=" + str(b.status) +
          " | etat_firebase=" + etat +
          " | poids=" + str(round(poids, 3)) + " kg")

print()
print("=== VERIFICATION FINALE ===")
print()
for b in bins:
    fb = get_bin_status(b.bin_code) or {}
    ok_type   = fb.get("bin_type") == b.bin_type
    ok_status = "status_sql" in fb
    ok_etat   = "etat" in fb
    status_line = "OK" if (ok_type and ok_status and ok_etat) else "VERIFIER"
    print("  [" + status_line + "] " + b.bin_code +
          " | SQL=" + str(b.status) +
          " | FB.etat=" + str(fb.get("etat")) +
          " | FB.poids=" + str(fb.get("poids")) +
          " | FB.status_sql=" + str(fb.get("status_sql")))

db.close()
