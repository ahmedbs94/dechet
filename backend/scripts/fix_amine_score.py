"""
fix_amine_score.py
-------------------
Corrige le score de amineT (user #16) a 164 pts dans PostgreSQL + Firebase.

Explication:
  - Anciens scans poubelle  = 147 pts (dans Firebase uniquement, pas dans PostgreSQL)
  - Quiz                    =  17 pts (quiz1=9 + quiz2=8)
  - Le scan du 30/04 (10pts) est inclus dans les 147
  - Vrai total              = 147 + 17 = 164 pts

Usage:
    cd backend
    python scripts/fix_amine_score.py
"""
import sys
import io
import os

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from database import SessionLocal
import db_models as m

VRAI_TOTAL = 164.0
USER_ID = 16

db = SessionLocal()
try:
    user = db.query(m.User).filter(m.User.id == USER_ID).first()
    if not user:
        print(f"[ERREUR] User #{USER_ID} introuvable dans PostgreSQL")
        sys.exit(1)

    ancien_score = user.global_score
    print(f"User: {user.full_name} (#{USER_ID})")
    print(f"Score actuel PostgreSQL : {ancien_score}")
    print(f"Score cible             : {VRAI_TOTAL}")
    print()

    # 1. Corriger PostgreSQL
    user.global_score = VRAI_TOTAL
    db.add(user)
    db.commit()
    db.refresh(user)
    print(f"[OK] PostgreSQL global_score mis a jour : {ancien_score} -> {user.global_score}")

    # 2. Corriger Firebase
    from services.firebase_service import _init_firebase
    if not _init_firebase():
        print("[WARN] Firebase indisponible - seul PostgreSQL a ete corrige")
        sys.exit(0)

    from firebase_admin import db as rtdb

    # /scores/16
    ref = rtdb.reference(f"scores/{USER_ID}")
    ref.update({"total": VRAI_TOTAL})
    print(f"[OK] Firebase /scores/{USER_ID}/total -> {VRAI_TOTAL}")

    # /utilisateurs/{qr_code}/score
    qr = user.qr_code or ""
    if qr:
        user_ref = rtdb.reference(f"utilisateurs/{qr}")
        user_data = user_ref.get()
        if user_data:
            user_ref.update({"score": VRAI_TOTAL})
            print(f"[OK] Firebase /utilisateurs/{qr[:30]}.../ score -> {VRAI_TOTAL}")
        else:
            print(f"[WARN] Noeud /utilisateurs/{qr} introuvable dans Firebase")
    else:
        print("[WARN] Pas de QR code pour cet utilisateur")

    # Verification
    print()
    print("=== Verification finale ===")
    db.refresh(user)
    score_data = ref.get()
    print(f"PostgreSQL global_score = {user.global_score}")
    print(f"Firebase /scores/{USER_ID}/total = {score_data.get('total') if score_data else 'N/A'}")
    if qr and user_data:
        updated = rtdb.reference(f"utilisateurs/{qr}").get()
        print(f"Firebase /utilisateurs/.../score = {updated.get('score') if updated else 'N/A'}")
    print()
    print("[OK] Correction terminee - score 164 pts synchronise partout")

finally:
    db.close()
