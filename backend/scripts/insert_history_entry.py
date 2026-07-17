import sys, io, os
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))
from database import SessionLocal
import db_models as m
from datetime import datetime

db = SessionLocal()

existing = db.query(m.BinScan).filter(
    m.BinScan.user_id == 16,
    m.BinScan.points_earned == 137.0,
).first()

if existing:
    print("Entree deja presente (id=" + str(existing.id) + "), rien a inserer.")
else:
    scan = m.BinScan(
        user_id         = 16,
        qr_code         = "TRIDECHET-8804aea0-0308-42a8-983d-e9edefcad4e4",
        smart_bin_id    = 1,
        bin_id          = "BIN-PLASTIQUE-001",
        waste_type      = "plastique",
        weight_kg       = None,
        points_earned   = 137.0,
        score_before    = 0.0,
        score_after     = 137.0,
        firebase_synced = True,
        scanned_at      = datetime(2026, 4, 28, 12, 0, 0),
    )
    db.add(scan)
    db.commit()
    db.refresh(scan)
    print("Entree inseree (id=" + str(scan.id) + ") : +137 pts | 28/04/2026")

print()
print("=== HISTORIQUE FINAL (tel que l'app le verra) ===")
print()

scans = db.query(m.BinScan).filter(m.BinScan.user_id == 16).order_by(m.BinScan.scanned_at.desc()).all()
quizzes = db.query(m.QuizSubmission).filter(m.QuizSubmission.student_id == 16).order_by(m.QuizSubmission.graded_at.desc()).all()

history = []
for s in scans:
    if s.points_earned and s.points_earned > 0:
        date_str = str(s.scanned_at)[:10]
        desc = "Tri de dechets - " + (s.waste_type or "general")
        history.append({"type": "Tri", "pts": s.points_earned, "date": date_str, "desc": desc})

for q in quizzes:
    if q.score and q.score > 0:
        date_str = str(q.graded_at)[:10]
        title = q.quiz.title if q.quiz else "Quiz"
        desc = "Quiz : " + title
        history.append({"type": "Quiz", "pts": q.score, "date": date_str, "desc": desc})

history.sort(key=lambda x: x["date"], reverse=True)

total = 0
for i, h in enumerate(history, 1):
    line = "  " + str(i) + ". [" + h["date"] + "]  +" + str(h["pts"]) + " pts  |  " + h["desc"]
    print(line)
    total += h["pts"]

user = db.query(m.User).filter(m.User.id == 16).first()
print()
print("  Somme historique = " + str(total) + " pts")
print("  global_score SQL = " + str(user.global_score) + " pts")
print()

diff = abs(float(total) - float(user.global_score))
if diff < 0.01:
    print("  [OK] Historique 100% coherent avec le score total")
else:
    print("  [ATTENTION] Ecart de " + str(round(diff, 2)) + " pts")

db.close()
