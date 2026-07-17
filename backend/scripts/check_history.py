import sys, io, os
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from database import SessionLocal
import db_models as m

db = SessionLocal()
user = db.query(m.User).filter(m.User.id == 16).first()

scans = db.query(m.BinScan).filter(
    m.BinScan.user_id == 16
).order_by(m.BinScan.scanned_at.desc()).all()

quizzes = db.query(m.QuizSubmission).filter(
    m.QuizSubmission.student_id == 16
).order_by(m.QuizSubmission.graded_at.desc()).all()

history = []

for s in scans:
    if s.points_earned and s.points_earned > 0:
        history.append({
            "type":   "Tri de dechets",
            "points": s.points_earned,
            "date":   s.scanned_at,
            "desc":   "Tri de dechets - " + (s.waste_type or "general"),
        })

for q in quizzes:
    if q.score and q.score > 0:
        quiz_title = q.quiz.title if q.quiz else "Quiz"
        history.append({
            "type":   "Quiz",
            "points": q.score,
            "date":   q.graded_at,
            "desc":   "Quiz complete : " + quiz_title,
        })

history.sort(key=lambda x: str(x["date"] or ""), reverse=True)

print("=== HISTORIQUE AMINE T. (tel que l'app le verra) ===")
print()
total_affiche = 0
for i, item in enumerate(history, 1):
    date_str = str(item["date"])[:10]
    print(f"  {i}. [{date_str}]  +{item['points']} pts  |  {item['desc']}")
    total_affiche += item["points"]

print()
print(f"  Somme de l'historique     = {total_affiche} pts")
print(f"  global_score PostgreSQL   = {user.global_score} pts")
print()

diff = round(float(user.global_score) - float(total_affiche), 2)
if diff == 0:
    print("  [OK] Historique coherent avec le score total")
else:
    print(f"  [ATTENTION] Ecart de {diff} pts")
    print(f"  => {diff} pts de scans anciens non traces dans BinScan (avant la mise en place du systeme)")

db.close()
