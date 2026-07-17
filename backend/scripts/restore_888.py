"""
restore_888.py
--------------
Restaure le vrai score d'Amine à 888 pts dans les 3 sources :
  - PostgreSQL   : users.global_score  (était périmé à 236)
  - Firebase     : /scores/16/total    (écrasé par erreur à 236)
  - Firebase     : /utilisateurs/{qr}/score  (écrasé par erreur à 236)

Cause : Des scans basés sur le poids ont mis à jour Firebase mais
        les BinScan SQL correspondants n'ont pas tous été enregistrés
        (ou global_score SQL n'a pas été mis à jour après ces scans).

Usage :
  cd backend
  python scripts/restore_888.py
"""
import sys, io, os

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from database import SessionLocal
import db_models as m
from services.firebase_service import _init_firebase
from datetime import datetime, timezone

USER_ID  = 16
QR_CODE  = "TRIDECHET-8804aea0-0308-42a8-983d-e9edefcad4e4"
VRAI_TOTAL = 888.0   # Score réel basé sur les poids scannés

print("=" * 60)
print("  RESTAURATION SCORE AMINE → 888 pts")
print("=" * 60)

# ── Firebase ──────────────────────────────────────────────────────────────────
print("\n[1] Connexion Firebase...")
ok = _init_firebase()
if not ok:
    print("[ERREUR] Firebase non disponible.")
    sys.exit(1)
print("    [OK] Firebase connecté")

from firebase_admin import db as rtdb

# ── PostgreSQL ────────────────────────────────────────────────────────────────
print(f"\n[2] Mise à jour PostgreSQL global_score → {VRAI_TOTAL} pts")
db = SessionLocal()
user = db.query(m.User).filter(m.User.id == USER_ID).first()
ancien_pg = float(user.global_score or 0)
user.global_score = VRAI_TOTAL
db.add(user)
db.commit()
db.refresh(user)
print(f"    [OK] PostgreSQL : {ancien_pg} → {user.global_score} pts")

# ── Firebase /scores/16 ───────────────────────────────────────────────────────
print(f"\n[3] Restauration Firebase /scores/{USER_ID}/total → {VRAI_TOTAL} pts")
ancien_fb = rtdb.reference(f"scores/{USER_ID}").get()
ancien_total = ancien_fb.get("total") if ancien_fb else "?"
rtdb.reference(f"scores/{USER_ID}").update({
    "total":         VRAI_TOTAL,
    "last_activity": datetime.now(timezone.utc).isoformat(),
    "last_source":   "admin_sync",
})
fb_after = rtdb.reference(f"scores/{USER_ID}").get()
print(f"    [OK] Firebase /scores/{USER_ID}/total : {ancien_total} → {fb_after.get('total') if fb_after else '?'} pts")

# ── Firebase /utilisateurs/{qr}/score ────────────────────────────────────────
print(f"\n[4] Restauration Firebase /utilisateurs/.../score → {VRAI_TOTAL} pts")
ancien_u = rtdb.reference(f"utilisateurs/{QR_CODE}").get()
ancien_u_score = ancien_u.get("score") if ancien_u else "?"
rtdb.reference(f"utilisateurs/{QR_CODE}").update({"score": VRAI_TOTAL})
fu_after = rtdb.reference(f"utilisateurs/{QR_CODE}").get()
print(f"    [OK] Firebase /utilisateurs/.../score : {ancien_u_score} → {fu_after.get('score') if fu_after else '?'} pts")

# ── Vérification finale ───────────────────────────────────────────────────────
print("\n" + "=" * 60)
print("  VÉRIFICATION FINALE")
print("=" * 60)
db.refresh(user)
fb_s2 = rtdb.reference(f"scores/{USER_ID}").get()
fb_u2 = rtdb.reference(f"utilisateurs/{QR_CODE}").get()

pg_final   = float(user.global_score or 0)
fb_s_final = float(fb_s2.get("total", 0)) if fb_s2 else 0.0
fb_u_final = float(fb_u2.get("score", 0)) if fb_u2 else 0.0

print(f"  PostgreSQL global_score        = {pg_final} pts")
print(f"  Firebase /scores/{USER_ID}/total    = {fb_s_final} pts")
print(f"  Firebase /utilisateurs/score   = {fb_u_final} pts")

all_ok = (
    abs(pg_final  - VRAI_TOTAL) < 0.01 and
    abs(fb_s_final - VRAI_TOTAL) < 0.01 and
    abs(fb_u_final - VRAI_TOTAL) < 0.01
)

print()
if all_ok:
    print(f"  ✅ Tout est synchronisé à {VRAI_TOTAL} pts !")
    print(f"  L'application affichera 888 pts au prochain rafraîchissement.")
else:
    print("  ⚠️  Des valeurs sont encore incorrectes :")
    if abs(pg_final - VRAI_TOTAL) >= 0.01:
        print(f"     PostgreSQL  attendu={VRAI_TOTAL}  obtenu={pg_final}")
    if abs(fb_s_final - VRAI_TOTAL) >= 0.01:
        print(f"     Firebase /scores  attendu={VRAI_TOTAL}  obtenu={fb_s_final}")
    if abs(fb_u_final - VRAI_TOTAL) >= 0.01:
        print(f"     Firebase /utilisateurs  attendu={VRAI_TOTAL}  obtenu={fb_u_final}")

print("=" * 60)
db.close()
