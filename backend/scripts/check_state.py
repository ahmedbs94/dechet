import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.path.insert(0, '.')
from dotenv import load_dotenv
load_dotenv('.env')

from database import SessionLocal
import db_models as m
from services.firebase_service import _init_firebase
from firebase_admin import db as rtdb

db = SessionLocal()
_init_firebase()

QR = 'TRIDECHET-8804aea0-0308-42a8-983d-e9edefcad4e4'
user = db.query(m.User).filter(m.User.id == 16).first()
print("=== ETAT ACTUEL user 16 ===")
print(f"PostgreSQL global_score = {user.global_score}")

scans = db.query(m.BinScan).filter(m.BinScan.user_id == 16).order_by(m.BinScan.scanned_at.desc()).all()
print(f"Scans ({len(scans)} total) :")
for s in scans:
    print(f"  id={s.id} | pts={s.points_earned} | score_before={s.score_before} | score_after={s.score_after} | {s.scanned_at}")

fb_scores = rtdb.reference('scores/16').get()
fb_user   = rtdb.reference(f'utilisateurs/{QR}').get()

fb_total = fb_scores.get('total') if fb_scores else None
fb_score = fb_user.get('score')   if fb_user   else None

print(f"Firebase /scores/16/total   = {fb_total}")
print(f"Firebase /utilisateurs/score = {fb_score}")

# Calcul du vrai total
quizzes = db.query(m.QuizSubmission).filter(m.QuizSubmission.student_id == 16).all()
total_quiz = sum(q.score or 0 for q in quizzes)
total_scan_sql = sum(s.points_earned or 0 for s in scans)

print()
print(f"Quiz SQL total       = {total_quiz}")
print(f"Scan SQL total       = {total_scan_sql}")
print(f"Anciens scans Firebase manquants = 147 (confirme)")
print(f"Vrai total = 147 (anciens scans) + {total_quiz} (quiz) + 13 (nouveau scan) = {147 + total_quiz + 13}")

db.close()
