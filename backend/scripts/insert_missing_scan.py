"""
insert_missing_scan.py
-----------------------
Insere le scan manquant de 13 pts pour amineT (user #16).

Ce scan a bien ete execute (Firebase l'a recu) mais n'a pas cree
d'enregistrement dans BinScan — il n'apparait donc pas dans l'historique.

Usage:
    cd backend
    python scripts/insert_missing_scan.py
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
from datetime import datetime

USER_ID      = 16
QR_CODE      = 'TRIDECHET-8804aea0-0308-42a8-983d-e9edefcad4e4'
POINTS       = 13.0
SCORE_BEFORE = 164.0   # score avant ce scan
SCORE_AFTER  = 177.0   # score apres ce scan
# Le scan etait sur la poubelle plastique (bin le plus commun)
# Si c'etait un autre type, modifier bin_code et waste_type
BIN_CODE     = 'BIN-PLASTIQUE-001'
WASTE_TYPE   = 'plastique'
SMART_BIN_ID = 1
# Date approximative du scan (aujourd'hui)
SCAN_DATE    = datetime(2026, 7, 11, 17, 50, 0)

db = SessionLocal()
try:
    # Verifier que le scan n'existe pas deja
    existing = db.query(m.BinScan).filter(
        m.BinScan.user_id == USER_ID,
        m.BinScan.points_earned == POINTS,
        m.BinScan.score_after == SCORE_AFTER,
    ).first()

    if existing:
        print(f"[INFO] Ce scan existe deja (id={existing.id}), rien a inserer.")
    else:
        scan = m.BinScan(
            user_id         = USER_ID,
            qr_code         = QR_CODE,
            smart_bin_id    = SMART_BIN_ID,
            bin_id          = BIN_CODE,
            waste_type      = WASTE_TYPE,
            weight_kg       = None,
            points_earned   = POINTS,
            score_before    = SCORE_BEFORE,
            score_after     = SCORE_AFTER,
            firebase_synced = True,
            scanned_at      = SCAN_DATE,
        )
        db.add(scan)
        db.commit()
        db.refresh(scan)
        print(f"[OK] Scan insere (id={scan.id})")
        print(f"     user_id={USER_ID} | pts={POINTS} | score_before={SCORE_BEFORE} | score_after={SCORE_AFTER}")
        print(f"     date={SCAN_DATE}")

    # Verification historique
    print()
    print("=== HISTORIQUE COMPLET user 16 ===")
    scans = db.query(m.BinScan).filter(m.BinScan.user_id == USER_ID).order_by(m.BinScan.scanned_at).all()
    for s in scans:
        print(f"  Scan  | {s.scanned_at} | +{s.points_earned} pts | {s.waste_type}")
    quizzes = db.query(m.QuizSubmission).filter(m.QuizSubmission.student_id == USER_ID).order_by(m.QuizSubmission.graded_at).all()
    for q in quizzes:
        print(f"  Quiz  | {q.graded_at} | +{q.score} pts")

    user = db.query(m.User).filter(m.User.id == USER_ID).first()
    print()
    print(f"global_score PostgreSQL = {user.global_score}")

finally:
    db.close()
