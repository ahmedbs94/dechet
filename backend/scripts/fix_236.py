import sys, io, os
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from database import SessionLocal
import db_models as m
from services.firebase_service import _init_firebase
from firebase_admin import db as rtdb
from datetime import datetime

QR         = "TRIDECHET-8804aea0-0308-42a8-983d-e9edefcad4e4"
USER_ID    = 16
NEW_PTS    = 59.0
SCORE_BEFORE = 177.0
VRAI_TOTAL = SCORE_BEFORE + NEW_PTS   # 236.0

db = SessionLocal()
_init_firebase()

user = db.query(m.User).filter(m.User.id == USER_ID).first()
print("Score avant correction : PostgreSQL=" + str(user.global_score))

# 1. Corriger PostgreSQL global_score
user.global_score = VRAI_TOTAL
db.add(user)
db.commit()
db.refresh(user)
print("[OK] PostgreSQL global_score -> " + str(user.global_score))

# 2. Corriger Firebase /scores/16/total
rtdb.reference("scores/" + str(USER_ID)).update({
    "total":         VRAI_TOTAL,
    "last_points":   NEW_PTS,
    "last_activity": datetime.utcnow().isoformat(),
    "last_source":   "scan",
})
print("[OK] Firebase /scores/16/total -> " + str(VRAI_TOTAL))

# 3. Corriger Firebase /utilisateurs/{qr}/score
rtdb.reference("utilisateurs/" + QR).update({"score": VRAI_TOTAL})
print("[OK] Firebase /utilisateurs/.../score -> " + str(VRAI_TOTAL))

# 4. Inserer le BinScan manquant (59 pts) dans l'historique
existing = db.query(m.BinScan).filter(
    m.BinScan.user_id == USER_ID,
    m.BinScan.points_earned == NEW_PTS,
    m.BinScan.score_after == VRAI_TOTAL,
).first()

if existing:
    print("BinScan 59 pts deja present (id=" + str(existing.id) + ")")
else:
    scan = m.BinScan(
        user_id         = USER_ID,
        qr_code         = QR,
        smart_bin_id    = 1,
        bin_id          = "BIN-PLASTIQUE-001",
        waste_type      = "plastique",
        weight_kg       = None,
        points_earned   = NEW_PTS,
        score_before    = SCORE_BEFORE,
        score_after     = VRAI_TOTAL,
        firebase_synced = True,
        scanned_at      = datetime(2026, 7, 11, 20, 20, 0),
    )
    db.add(scan)
    db.commit()
    db.refresh(scan)
    print("[OK] BinScan insere (id=" + str(scan.id) + ") : +59 pts | 11/07/2026")

# 5. Verification finale
print()
print("=== VERIFICATION FINALE ===")
db.refresh(user)
fb_s = rtdb.reference("scores/" + str(USER_ID)).get()
fb_u = rtdb.reference("utilisateurs/" + QR).get()

pg  = user.global_score
fs  = fb_s.get("total") if fb_s else None
fu  = fb_u.get("score") if fb_u else None

print("PostgreSQL global_score        = " + str(pg))
print("Firebase /scores/total         = " + str(fs))
print("Firebase /utilisateurs/score   = " + str(fu))
print()

scans = db.query(m.BinScan).filter(m.BinScan.user_id == USER_ID).order_by(m.BinScan.scanned_at.desc()).all()
quizzes = db.query(m.QuizSubmission).filter(m.QuizSubmission.student_id == USER_ID).order_by(m.QuizSubmission.graded_at.desc()).all()

history = []
for s in scans:
    if s.points_earned and s.points_earned > 0:
        history.append({"pts": s.points_earned, "date": str(s.scanned_at)[:10], "desc": "Tri - " + (s.waste_type or "general")})
for q in quizzes:
    if q.score and q.score > 0:
        title = q.quiz.title if q.quiz else "Quiz"
        history.append({"pts": q.score, "date": str(q.graded_at)[:10], "desc": "Quiz : " + title})

history.sort(key=lambda x: x["date"], reverse=True)
total = 0
print("Historique app :")
for i, h in enumerate(history, 1):
    print("  " + str(i) + ". [" + h["date"] + "]  +" + str(h["pts"]) + " pts  |  " + h["desc"])
    total += h["pts"]

print()
print("Somme historique = " + str(total) + " pts")

if abs(float(pg) - float(total)) < 0.01 == abs(float(pg) - VRAI_TOTAL) < 0.01:
    pass

if abs(float(total) - VRAI_TOTAL) < 0.01 and abs(float(pg) - VRAI_TOTAL) < 0.01:
    print("[OK] Tout est synchronise a " + str(VRAI_TOTAL) + " pts !")
else:
    print("[WARN] Verifier manuellement")

db.close()
