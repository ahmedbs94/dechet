"""
EcoRewind Quiz Router
======================
Endpoints pour le système de quiz automatique avec correction IA (Gemini).

Flux :
  1. Éducateur upload un PDF quiz → Gemini extrait les questions
  2. Étudiants soumettent leurs réponses (JSON ou PDF)
  3. Gemini corrige et attribue une note /10
"""

import os
import json
import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy.orm import Session
from sqlalchemy import desc

import db_models as db_models
from database import get_db
from core.deps import get_current_user, _utc_iso

router = APIRouter(prefix="/quiz", tags=["quiz"])

UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads")
os.makedirs(os.path.join(UPLOADS_DIR, "quizzes"), exist_ok=True)


def _format_quiz(q: db_models.Quiz) -> dict:
    """Formatte un quiz pour la réponse API."""
    questions = []
    if q.questions_json:
        try:
            questions = json.loads(q.questions_json)
        except:
            pass
    return {
        "id": q.id,
        "educator_id": q.educator_id,
        "title": q.title,
        "description": q.description or "",
        "total_questions": q.total_questions,
        "status": q.status,
        "error_message": q.error_message,
        "questions": questions,
        "created_at": _utc_iso(q.created_at),
        "submissions_count": len(q.submissions) if q.submissions else 0,
    }


def _format_submission(s: db_models.QuizSubmission) -> dict:
    """Formatte une soumission pour la réponse API."""
    details = []
    if s.feedback_json:
        try:
            details = json.loads(s.feedback_json)
        except:
            pass
    answers = {}
    if s.answers_json:
        try:
            answers = json.loads(s.answers_json)
        except:
            pass
    return {
        "id": s.id,
        "quiz_id": s.quiz_id,
        "student_id": s.student_id,
        "student_name": s.student_name,
        "score": s.score,
        "max_score": s.max_score,
        "ai_graded": s.ai_graded,
        "answers": answers,
        "feedback": details,
        "submitted_at": _utc_iso(s.submitted_at),
        "graded_at": _utc_iso(s.graded_at),
    }


# ═══════════════════════════════════════════════════════════════════════════════
#  ÉDUCATEUR : Créer un quiz à partir d'un PDF
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/create")
async def create_quiz_from_pdf(
    file: UploadFile = File(...),
    title: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    L'éducateur upload un PDF de quiz.
    Gemini extrait automatiquement les questions et les réponses correctes.
    """
    # Vérifier le type de fichier
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Seuls les fichiers PDF sont acceptés.")

    # Lire le contenu
    pdf_bytes = await file.read()
    if len(pdf_bytes) > 20 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Fichier trop volumineux (max 20 Mo).")

    # Sauvegarder le PDF
    pdf_name = f"quiz_{uuid.uuid4().hex}.pdf"
    pdf_path = os.path.join(UPLOADS_DIR, "quizzes", pdf_name)
    with open(pdf_path, "wb") as f:
        f.write(pdf_bytes)

    # Créer l'entrée en DB (status = processing)
    quiz = db_models.Quiz(
        educator_id=current_user.id,
        title=title or file.filename.replace(".pdf", ""),
        description=description,
        pdf_filename=pdf_name,
        status="processing",
    )
    db.add(quiz)
    db.commit()
    db.refresh(quiz)

    # Appeler Gemini pour extraire les questions
    try:
        from services.gemini_quiz import extract_quiz_from_pdf

        result = extract_quiz_from_pdf(pdf_bytes)

        questions = result.get("questions", [])
        quiz.title = title or result.get("title", quiz.title)
        quiz.questions_json = json.dumps(questions, ensure_ascii=False)
        quiz.answer_key_json = json.dumps(
            [{
                "number": q.get("number"),
                "correct_answer": q.get("correct_answer"),
                "explanation": q.get("explanation", ""),
            } for q in questions],
            ensure_ascii=False,
        )
        quiz.total_questions = len(questions)
        quiz.status = "ready"

        db.commit()
        db.refresh(quiz)

        return {
            "message": f"Quiz créé avec succès ! {len(questions)} questions extraites par l'IA.",
            "quiz": _format_quiz(quiz),
        }

    except Exception as e:
        quiz.status = "error"
        quiz.error_message = str(e)[:500]
        db.commit()
        raise HTTPException(status_code=500, detail=f"Erreur IA Gemini : {str(e)[:200]}")


@router.post("/{quiz_id}/retry")
async def retry_quiz_extraction(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Re-tenter l'extraction Gemini pour un quiz en erreur."""
    quiz = db.query(db_models.Quiz).filter(
        db_models.Quiz.id == quiz_id,
        db_models.Quiz.educator_id == current_user.id,
    ).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz non trouvé")
    if quiz.status == "ready":
        return {"message": "Ce quiz est déjà prêt.", "quiz": _format_quiz(quiz)}

    pdf_path = os.path.join(UPLOADS_DIR, "quizzes", quiz.pdf_filename)
    if not os.path.exists(pdf_path):
        raise HTTPException(status_code=404, detail="Fichier PDF introuvable.")

    try:
        with open(pdf_path, "rb") as f:
            pdf_bytes = f.read()

        from services.gemini_quiz import extract_quiz_from_pdf
        result = extract_quiz_from_pdf(pdf_bytes)

        questions = result.get("questions", [])
        quiz.title = result.get("title", quiz.title)
        quiz.questions_json = json.dumps(questions, ensure_ascii=False)
        quiz.answer_key_json = json.dumps(
            [{"number": q.get("number"), "correct_answer": q.get("correct_answer"),
              "explanation": q.get("explanation", "")} for q in questions],
            ensure_ascii=False,
        )
        quiz.total_questions = len(questions)
        quiz.status = "ready"
        quiz.error_message = None
        db.commit()
        db.refresh(quiz)

        return {
            "message": f"Quiz re-traité avec succès ! {len(questions)} questions extraites.",
            "quiz": _format_quiz(quiz),
        }
    except Exception as e:
        quiz.error_message = str(e)[:500]
        db.commit()
        raise HTTPException(status_code=500, detail=f"Erreur IA Gemini : {str(e)[:200]}")


# ═══════════════════════════════════════════════════════════════════════════════
#  CITOYEN : Voir tous les quiz disponibles
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/available")
async def get_available_quizzes(
    db: Session = Depends(get_db),
):
    """Liste tous les quiz prêts (accessible à tous)."""
    quizzes = (
        db.query(db_models.Quiz)
        .filter(db_models.Quiz.status == "ready")
        .order_by(desc(db_models.Quiz.created_at))
        .all()
    )
    # Retourner les quiz SANS les réponses correctes
    result = []
    for q in quizzes:
        formatted = _format_quiz(q)
        for question in formatted.get("questions", []):
            question.pop("correct_answer", None)
            question.pop("explanation", None)
        result.append(formatted)
    return {"quizzes": result}


# ═══════════════════════════════════════════════════════════════════════════════
#  ÉDUCATEUR : Liste des quiz créés
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/my-quizzes")
async def get_my_quizzes(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Liste les quiz créés par l'éducateur connecté."""
    quizzes = (
        db.query(db_models.Quiz)
        .filter(db_models.Quiz.educator_id == current_user.id)
        .order_by(desc(db_models.Quiz.created_at))
        .all()
    )
    return {"quizzes": [_format_quiz(q) for q in quizzes]}


# ═══════════════════════════════════════════════════════════════════════════════
#  ÉTUDIANT : Voir un quiz (questions sans réponses)
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/{quiz_id}")
async def get_quiz(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Récupère un quiz (les réponses correctes sont masquées pour les étudiants)."""
    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz non trouvé")
    if quiz.status != "ready":
        raise HTTPException(status_code=400, detail="Ce quiz n'est pas encore prêt.")

    result = _format_quiz(quiz)

    # Masquer les réponses correctes pour les étudiants (sauf si éducateur)
    is_educator = current_user.id == quiz.educator_id or current_user.role in ["admin", "superadmin"]
    if not is_educator:
        for q in result["questions"]:
            q.pop("correct_answer", None)
            q.pop("explanation", None)

    return result


# ═══════════════════════════════════════════════════════════════════════════════
#  ÉTUDIANT : Soumettre les réponses (JSON)
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/{quiz_id}/submit")
async def submit_quiz_answers(
    quiz_id: int,
    answers: dict,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    L'étudiant soumet ses réponses au format JSON :
    { "1": "A", "2": "Vrai", "3": "Le recyclage permet de...", ... }

    Gemini corrige automatiquement et attribue une note /10.
    """
    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()
    if not quiz or quiz.status != "ready":
        raise HTTPException(status_code=404, detail="Quiz non trouvé ou pas encore prêt")

    # Vérifier si l'utilisateur a déjà soumis ce quiz
    existing = (
        db.query(db_models.QuizSubmission)
        .filter(
            db_models.QuizSubmission.quiz_id == quiz_id,
            db_models.QuizSubmission.student_id == current_user.id,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"Vous avez déjà complété ce quiz avec un score de {existing.score}/10. Chaque quiz ne peut être passé qu'une seule fois."
        )

    # Charger les questions
    questions = json.loads(quiz.questions_json) if quiz.questions_json else []
    if not questions:
        raise HTTPException(status_code=400, detail="Aucune question dans ce quiz")

    # Corriger via Gemini
    try:
        from services.gemini_quiz import grade_submission

        grading = grade_submission(questions, answers)

        submission = db_models.QuizSubmission(
            quiz_id=quiz_id,
            student_id=current_user.id,
            student_name=current_user.full_name or current_user.email,
            answers_json=json.dumps(answers, ensure_ascii=False),
            score=round(grading.get("score", 0), 1),
            max_score=10.0,
            feedback_json=json.dumps(grading, ensure_ascii=False),
            ai_graded=True,
            graded_at=datetime.utcnow(),
        )
        db.add(submission)

        # Ajouter le score au score global de l'utilisateur
        score = round(grading.get("score", 0), 1)
        if score > 0:
            if current_user.global_score is None:
                current_user.global_score = 0.0
            current_user.global_score += score
            db.add(current_user)

        db.commit()
        db.refresh(submission)

        return {
            "message": "Quiz corrigé par l'IA !",
            "submission": _format_submission(submission),
            "grading": grading,
            "global_score": current_user.global_score or 0.0,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur correction IA : {str(e)[:200]}")


# ═══════════════════════════════════════════════════════════════════════════════
#  ÉTUDIANT : Soumettre un PDF de réponses
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/{quiz_id}/submit-pdf")
async def submit_quiz_pdf(
    quiz_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    L'étudiant upload un PDF avec ses réponses.
    Gemini compare avec le quiz original et attribue une note /10.
    """
    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()
    if not quiz or quiz.status != "ready":
        raise HTTPException(status_code=404, detail="Quiz non trouvé ou pas encore prêt")

    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Seuls les fichiers PDF sont acceptés.")

    submission_bytes = await file.read()

    # Charger le PDF du quiz original
    quiz_pdf_path = os.path.join(UPLOADS_DIR, "quizzes", quiz.pdf_filename)
    if not os.path.exists(quiz_pdf_path):
        raise HTTPException(status_code=500, detail="PDF du quiz original introuvable")

    with open(quiz_pdf_path, "rb") as f:
        quiz_pdf_bytes = f.read()

    # Correction via Gemini (2 PDFs)
    try:
        from services.gemini_quiz import grade_pdf_submission

        grading = grade_pdf_submission(quiz_pdf_bytes, submission_bytes)

        submission = db_models.QuizSubmission(
            quiz_id=quiz_id,
            student_id=current_user.id,
            student_name=current_user.full_name or current_user.email,
            answers_json=json.dumps({"source": "pdf", "filename": file.filename}, ensure_ascii=False),
            score=round(grading.get("score", 0), 1),
            max_score=10.0,
            feedback_json=json.dumps(grading, ensure_ascii=False),
            ai_graded=True,
            graded_at=datetime.utcnow(),
        )
        db.add(submission)

        # Ajouter le score au score global de l'utilisateur
        score = round(grading.get("score", 0), 1)
        if score > 0:
            if current_user.global_score is None:
                current_user.global_score = 0.0
            current_user.global_score += score
            db.add(current_user)

        db.commit()
        db.refresh(submission)

        return {
            "message": "Copie corrigée par l'IA !",
            "submission": _format_submission(submission),
            "grading": grading,
            "global_score": current_user.global_score or 0.0,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur correction IA : {str(e)[:200]}")


# ═══════════════════════════════════════════════════════════════════════════════
#  ÉDUCATEUR : Voir les résultats d'un quiz
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/{quiz_id}/results")
async def get_quiz_results(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Récupère tous les résultats/soumissions d'un quiz (éducateur uniquement)."""
    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz non trouvé")

    # Seuls l'éducateur créateur et les admins peuvent voir les résultats
    if current_user.id != quiz.educator_id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Accès non autorisé")

    submissions = (
        db.query(db_models.QuizSubmission)
        .filter(db_models.QuizSubmission.quiz_id == quiz_id)
        .order_by(desc(db_models.QuizSubmission.submitted_at))
        .all()
    )

    # Calcul des stats
    scores = [s.score for s in submissions if s.score is not None]
    avg_score = round(sum(scores) / len(scores), 1) if scores else 0
    max_score = max(scores) if scores else 0
    min_score = min(scores) if scores else 0

    return {
        "quiz": _format_quiz(quiz),
        "stats": {
            "total_submissions": len(submissions),
            "average_score": avg_score,
            "highest_score": max_score,
            "lowest_score": min_score,
        },
        "submissions": [_format_submission(s) for s in submissions],
    }


# ═══════════════════════════════════════════════════════════════════════════════
#  ÉTUDIANT : Voir son résultat
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/{quiz_id}/my-result")
async def get_my_result(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """L'étudiant récupère son propre résultat pour un quiz."""
    submission = (
        db.query(db_models.QuizSubmission)
        .filter(
            db_models.QuizSubmission.quiz_id == quiz_id,
            db_models.QuizSubmission.student_id == current_user.id,
        )
        .order_by(desc(db_models.QuizSubmission.submitted_at))
        .first()
    )
    if not submission:
        raise HTTPException(status_code=404, detail="Aucune soumission trouvée")

    return _format_submission(submission)


# ═══════════════════════════════════════════════════════════════════════════════
#  ÉDUCATEUR : Supprimer un quiz (et son PDF)
# ═══════════════════════════════════════════════════════════════════════════════

@router.delete("/{quiz_id}")
async def delete_quiz(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Supprime un quiz et son fichier PDF associé (éducateur créateur ou admin)."""
    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz non trouvé")
    if quiz.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")

    # Supprimer le fichier PDF si présent
    if quiz.pdf_filename:
        pdf_path = os.path.join(UPLOADS_DIR, "quizzes", quiz.pdf_filename)
        if os.path.exists(pdf_path):
            try:
                os.remove(pdf_path)
            except OSError:
                pass  # Fichier déjà supprimé ou inaccessible

    # Supprimer les soumissions associées
    db.query(db_models.QuizSubmission).filter(
        db_models.QuizSubmission.quiz_id == quiz_id
    ).delete()

    db.delete(quiz)
    db.commit()
    return {"message": "Quiz supprimé avec succès"}
