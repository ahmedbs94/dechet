"""
fix_score_amine.py
------------------
Synchronise le score de l'utilisateur Amine (id=16) entre :
  - PostgreSQL   : users.global_score
  - Firebase     : /scores/16/total
  - Firebase     : /utilisateurs/{qr_code}/score

Problème détecté :
  Firebase /utilisateurs/{qr} affiche 888 pts
  L'application affiche 236 pts (valeur SQL périmée)

Ce script :
  1. Lit le vrai total depuis Firebase /scores/16/total (source de vérité)
  2. Met à jour PostgreSQL global_score avec ce total
  3. Synchronise Firebase /utilisateurs/{qr}/score
  4. Affiche un rapport de vérification complet

Usage :
  cd backend
  python scripts/fix_score_amine.py
"""
import sys, io, os

# Encodage UTF-8 robuste sous Windows
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# Ajouter le dossier backend au path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from database import SessionLocal
import db_models as m
from sqlalchemy import func
from services.firebase_service import _init_firebase

# ── Identifiants d'Amine ──────────────────────────────────────────────────────
USER_ID = 16
QR_CODE = "TRIDECHET-8804aea0-0308-42a8-983d-e9edefcad4e4"

print("=" * 60)
print("  SYNCHRONISATION SCORE AMINE (id=16)")
print("=" * 60)

# ── 1. Initialiser Firebase ───────────────────────────────────────────────────
print("\n[1] Connexion Firebase...")
ok = _init_firebase()
if not ok:
    print("[ERREUR] Firebase non disponible. Vérifiez .env et firebase_credentials.json")
    sys.exit(1)
print("    [OK] Firebase connecté")

from firebase_admin import db as rtdb

# ── 2. Lire les valeurs actuelles ─────────────────────────────────────────────
print("\n[2] Lecture des valeurs actuelles...")

db = SessionLocal()
user = db.query(m.User).filter(m.User.id == USER_ID).first()
if not user:
    print(f"[ERREUR] Utilisateur id={USER_ID} introuvable dans PostgreSQL")
    db.close()
    sys.exit(1)

pg_score = float(user.global_score or 0.0)
print(f"    PostgreSQL global_score      = {pg_score} pts")

fb_scores = rtdb.reference(f"scores/{USER_ID}").get()
fb_total  = float(fb_scores.get("total", 0.0)) if fb_scores else 0.0
print(f"    Firebase /scores/{USER_ID}/total  = {fb_total} pts")

fb_utilisateur = rtdb.reference(f"utilisateurs/{QR_CODE}").get()
fb_user_score  = float(fb_utilisateur.get("score", 0.0)) if fb_utilisateur else 0.0
print(f"    Firebase /utilisateurs/score = {fb_user_score} pts")

# ── 3. Recalculer le vrai total depuis les tables sources ─────────────────────
print("\n[3] Recalcul depuis BinScan + QuizSubmission (source de vérité SQL)...")

scan_total = db.query(
    func.coalesce(func.sum(m.BinScan.points_earned), 0.0)
).filter(m.BinScan.user_id == USER_ID).scalar()

quiz_total = db.query(
    func.coalesce(func.sum(m.QuizSubmission.score), 0.0)
).filter(m.QuizSubmission.student_id == USER_ID).scalar()

sql_computed = round(float(scan_total) + float(quiz_total), 2)
print(f"    Scans      = {float(scan_total):.2f} pts")
print(f"    Quiz       = {float(quiz_total):.2f} pts")
print(f"    TOTAL SQL  = {sql_computed} pts")

# ── 4. Choisir la source de vérité : Firebase /scores/{id}/total ──────────────
# Firebase est mis à jour par le backend en temps réel après chaque scan/quiz.
# Si Firebase > SQL calculé, c'est Firebase qui a raison (des entrées BinScan/Quiz
# ont peut-être été insérées directement sans recalcul SQL).
# Si SQL calculé > Firebase, c'est SQL qui a raison.
VRAI_TOTAL = max(fb_total, sql_computed)
print(f"\n    Source de vérité choisie     = {VRAI_TOTAL} pts")

if abs(pg_score - VRAI_TOTAL) < 0.01 and abs(fb_user_score - VRAI_TOTAL) < 0.01:
    print("\n[OK] Tout est déjà synchronisé. Aucune correction nécessaire.")
    db.close()
    sys.exit(0)

# ── 5. Corriger PostgreSQL ────────────────────────────────────────────────────
print(f"\n[4] Mise à jour PostgreSQL : {pg_score} → {VRAI_TOTAL} pts")
user.global_score = VRAI_TOTAL
db.add(user)
db.commit()
db.refresh(user)
print(f"    [OK] PostgreSQL global_score = {user.global_score} pts")

# ── 6. Corriger Firebase /scores/{user_id} ────────────────────────────────────
print(f"\n[5] Mise à jour Firebase /scores/{USER_ID}...")
from datetime import datetime, timezone
rtdb.reference(f"scores/{USER_ID}").update({
    "total":         VRAI_TOTAL,
    "last_activity": datetime.now(timezone.utc).isoformat(),
    "last_source":   "admin_sync",
})
fb_scores_after = rtdb.reference(f"scores/{USER_ID}").get()
print(f"    [OK] Firebase /scores/{USER_ID}/total = {fb_scores_after.get('total') if fb_scores_after else '?'} pts")

# ── 7. Corriger Firebase /utilisateurs/{qr}/score ────────────────────────────
print(f"\n[6] Mise à jour Firebase /utilisateurs/{QR_CODE[:30]}...")
rtdb.reference(f"utilisateurs/{QR_CODE}").update({"score": VRAI_TOTAL})
fb_utilisateur_after = rtdb.reference(f"utilisateurs/{QR_CODE}").get()
fu_after = fb_utilisateur_after.get("score") if fb_utilisateur_after else "?"
print(f"    [OK] Firebase /utilisateurs/.../score = {fu_after} pts")

# ── 8. Rapport de vérification ────────────────────────────────────────────────
print("\n" + "=" * 60)
print("  RAPPORT DE VÉRIFICATION FINALE")
print("=" * 60)

db.refresh(user)
fb_s2 = rtdb.reference(f"scores/{USER_ID}").get()
fb_u2 = rtdb.reference(f"utilisateurs/{QR_CODE}").get()

pg_final  = float(user.global_score or 0.0)
fb_s_final = float(fb_s2.get("total", 0)) if fb_s2 else 0.0
fb_u_final = float(fb_u2.get("score", 0)) if fb_u2 else 0.0

print(f"  PostgreSQL global_score          = {pg_final} pts")
print(f"  Firebase /scores/{USER_ID}/total      = {fb_s_final} pts")
print(f"  Firebase /utilisateurs/score     = {fb_u_final} pts")

# Lister l'historique complet
scans = db.query(m.BinScan).filter(m.BinScan.user_id == USER_ID).order_by(m.BinScan.scanned_at.asc()).all()
quizzes = db.query(m.QuizSubmission).filter(m.QuizSubmission.student_id == USER_ID).order_by(m.QuizSubmission.graded_at.asc()).all()

print(f"\n  Historique BinScan ({len(scans)} scans) :")
total_s = 0
for s in scans:
    pts = float(s.points_earned or 0)
    total_s += pts
    date = str(s.scanned_at)[:10] if s.scanned_at else "?"
    print(f"    [{date}] +{pts:.1f} pts  | {s.waste_type or 'général'} | score_after={s.score_after}")

print(f"\n  Historique QuizSubmission ({len(quizzes)} quiz) :")
total_q = 0
for q in quizzes:
    pts = float(q.score or 0)
    total_q += pts
    date = str(q.graded_at)[:10] if q.graded_at else "?"
    title = q.quiz.title if q.quiz else f"quiz#{q.quiz_id}"
    print(f"    [{date}] +{pts:.1f} pts  | {title}")

grand_total = round(total_s + total_q, 2)
print(f"\n  Somme scans  = {total_s:.2f} pts")
print(f"  Somme quiz   = {total_q:.2f} pts")
print(f"  GRAND TOTAL  = {grand_total} pts")

# Vérification cohérence
all_ok = (
    abs(pg_final - VRAI_TOTAL) < 0.01 and
    abs(fb_s_final - VRAI_TOTAL) < 0.01 and
    abs(fb_u_final - VRAI_TOTAL) < 0.01
)

print()
if all_ok:
    print(f"  ✅ Tout est synchronisé à {VRAI_TOTAL} pts !")
    print(f"  L'application affichera {VRAI_TOTAL} pts au prochain rafraîchissement.")
else:
    print("  ⚠️  Vérifier manuellement les valeurs ci-dessus.")

print("=" * 60)
db.close()
