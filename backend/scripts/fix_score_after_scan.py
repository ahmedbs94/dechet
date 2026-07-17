"""
fix_score_after_scan.py
-----------------------
Corrige le score de amineT (user #16) apres le nouveau scan.

Situation :
  - PostgreSQL global_score = 164.0 (notre correction d'hier)
  - Firebase /utilisateurs/score = 100  (le scan a ecrase avec une mauvaise valeur)
  - Firebase /scores/16/total   = 164   (correct)
  - Nouveau scan de 13 pts non encore enregistre dans PostgreSQL

Vrai total correct = 164 (avant scan) + 13 (nouveau scan) = 177 pts

Usage:
    cd backend
    python scripts/fix_score_after_scan.py
"""
import sys, io, os
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from database import SessionLocal
import db_models as m
from services.firebase_service import _init_firebase
from firebase_admin import db as rtdb

QR         = 'TRIDECHET-8804aea0-0308-42a8-983d-e9edefcad4e4'
USER_ID    = 16
VRAI_TOTAL = 177.0  # 164 (avant scan) + 13 (nouveau scan)

db = SessionLocal()
_init_firebase()

user = db.query(m.User).filter(m.User.id == USER_ID).first()
print(f"User: {user.full_name} (#{USER_ID})")
print(f"PostgreSQL global_score actuel = {user.global_score}")

# 1. Corriger PostgreSQL
user.global_score = VRAI_TOTAL
db.add(user)
db.commit()
db.refresh(user)
print(f"[OK] PostgreSQL -> {user.global_score}")

# 2. Corriger Firebase /scores/{id}
rtdb.reference(f'scores/{USER_ID}').update({'total': VRAI_TOTAL})
print(f"[OK] Firebase /scores/{USER_ID}/total -> {VRAI_TOTAL}")

# 3. Corriger Firebase /utilisateurs/{qr}/score
rtdb.reference(f'utilisateurs/{QR}').update({'score': VRAI_TOTAL})
print(f"[OK] Firebase /utilisateurs/.../score -> {VRAI_TOTAL}")

# 4. Verification
print()
print("=== VERIFICATION ===")
db.refresh(user)
fb_s = rtdb.reference(f'scores/{USER_ID}').get()
fb_u = rtdb.reference(f'utilisateurs/{QR}').get()
print(f"PostgreSQL = {user.global_score}")
print(f"Firebase /scores/total = {fb_s.get('total') if fb_s else 'N/A'}")
print(f"Firebase /utilisateurs/score = {fb_u.get('score') if fb_u else 'N/A'}")
print()

if user.global_score == fb_s.get('total') == fb_u.get('score') == VRAI_TOTAL:
    print("[OK] Score 177.0 synchronise partout !")
else:
    print("[WARN] Verifier manuellement les valeurs")

db.close()
