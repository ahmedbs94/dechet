"""
patch_quiz.py — Applique le fix source-de-verite dans quiz.py
"""
import io, os, sys

quiz_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "routers", "quiz.py")

with io.open(quiz_path, "r", encoding="utf-8") as f:
    content = f.read()

# ─── Patch 1 : submit JSON (lines ~344-355) ───────────────────────────────────
OLD1 = (
    '        db.add(submission)\n'
    '\n'
    "        # Ajouter le score au score global de l'utilisateur\n"
    '        score = round(grading.get("score", 0), 1)\n'
    '        if score > 0:\n'
    '            if current_user.global_score is None:\n'
    '                current_user.global_score = 0.0\n'
    '            current_user.global_score += score\n'
    '            db.add(current_user)\n'
    '\n'
    '        db.commit()\n'
    '        db.refresh(submission)\n'
    '\n'
    '        # \u2500\u2500 Sync Firebase RTDB (hors transaction SQL, non bloquant) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n'
    '        # Systeme independant du scan de poubelle : on utilise update_quiz_score.\n'
)

NEW1 = (
    '        db.add(submission)\n'
    '\n'
    '        # SOURCE DE VERITE : recalcul depuis BinScan + QuizSubmission\n'
    '        # On commit la soumission, puis on relit les vraies sommes SQL.\n'
    '        score = round(grading.get("score", 0), 1)\n'
    '        db.commit()\n'
    '        db.refresh(submission)\n'
    '\n'
    '        if score > 0:\n'
    '            from sqlalchemy import func as _func\n'
    '            _scan_pts = db.query(\n'
    '                _func.coalesce(_func.sum(db_models.BinScan.points_earned), 0.0)\n'
    '            ).filter(db_models.BinScan.user_id == current_user.id).scalar()\n'
    '            _quiz_pts = db.query(\n'
    '                _func.coalesce(_func.sum(db_models.QuizSubmission.score), 0.0)\n'
    '            ).filter(db_models.QuizSubmission.student_id == current_user.id).scalar()\n'
    '            current_user.global_score = round(float(_scan_pts) + float(_quiz_pts), 2)\n'
    '            db.add(current_user)\n'
    '            db.commit()\n'
    '\n'
    '        # \u2500\u2500 Sync Firebase RTDB (hors transaction SQL, non bloquant) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n'
    '        # Systeme independant du scan de poubelle : on utilise update_quiz_score.\n'
)

# ─── Patch 2 : submit PDF (lines ~432-443) ────────────────────────────────────
OLD2 = (
    '        db.add(submission)\n'
    '\n'
    "        # Ajouter le score au score global de l'utilisateur\n"
    '        score = round(grading.get("score", 0), 1)\n'
    '        if score > 0:\n'
    '            if current_user.global_score is None:\n'
    '                current_user.global_score = 0.0\n'
    '            current_user.global_score += score\n'
    '            db.add(current_user)\n'
    '\n'
    '        db.commit()\n'
    '        db.refresh(submission)\n'
    '\n'
    '        # \u2500\u2500 Sync Firebase RTDB (hors transaction SQL, non bloquant) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n'
    '        # Systeme independant du scan de poubelle.\n'
)

NEW2 = (
    '        db.add(submission)\n'
    '\n'
    '        # SOURCE DE VERITE : recalcul depuis BinScan + QuizSubmission (idem submit JSON)\n'
    '        score = round(grading.get("score", 0), 1)\n'
    '        db.commit()\n'
    '        db.refresh(submission)\n'
    '\n'
    '        if score > 0:\n'
    '            from sqlalchemy import func as _func\n'
    '            _scan_pts = db.query(\n'
    '                _func.coalesce(_func.sum(db_models.BinScan.points_earned), 0.0)\n'
    '            ).filter(db_models.BinScan.user_id == current_user.id).scalar()\n'
    '            _quiz_pts = db.query(\n'
    '                _func.coalesce(_func.sum(db_models.QuizSubmission.score), 0.0)\n'
    '            ).filter(db_models.QuizSubmission.student_id == current_user.id).scalar()\n'
    '            current_user.global_score = round(float(_scan_pts) + float(_quiz_pts), 2)\n'
    '            db.add(current_user)\n'
    '            db.commit()\n'
    '\n'
    '        # \u2500\u2500 Sync Firebase RTDB (hors transaction SQL, non bloquant) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n'
    '        # Systeme independant du scan de poubelle.\n'
)

# Apply patches
n1 = content.count(OLD1)
n2 = content.count(OLD2)
print(f"Patch 1 matches: {n1}")
print(f"Patch 2 matches: {n2}")

if n1 != 1:
    print("[ERREUR] Patch 1 : correspondance non unique ou introuvable")
    sys.exit(1)
if n2 != 1:
    print("[ERREUR] Patch 2 : correspondance non unique ou introuvable")
    sys.exit(1)

content = content.replace(OLD1, NEW1, 1)
content = content.replace(OLD2, NEW2, 1)

with io.open(quiz_path, "w", encoding="utf-8") as f:
    f.write(content)

print("[OK] quiz.py patche avec succes")
print("     Patch 1 : submit JSON — source-de-verite appliquee")
print("     Patch 2 : submit PDF  — source-de-verite appliquee")
