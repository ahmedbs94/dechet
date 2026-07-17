import sys, io, os
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from services.firebase_service import _init_firebase
_init_firebase()
from firebase_admin import db as rtdb

# Lire tous les noeuds Firebase lies aux poubelles
print("=== Firebase : noeud /poubelles ===")
poubelles = rtdb.reference("poubelles").get()
if poubelles:
    for code, data in poubelles.items():
        print("  " + code + " : " + str(data))
else:
    print("  (vide)")

print()
print("=== Firebase : noeud /smart_bins ===")
smart_bins = rtdb.reference("smart_bins").get()
if smart_bins:
    for code, data in smart_bins.items():
        print("  " + code + " : " + str(data))
else:
    print("  (vide)")

print()
print("=== Firebase : noeud /bins ===")
bins = rtdb.reference("bins").get()
if bins:
    for code, data in bins.items():
        print("  " + code + " : " + str(data))
else:
    print("  (vide)")
