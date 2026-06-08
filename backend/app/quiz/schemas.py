"""
app/quiz/schemas.py — Schémas Pydantic : Quiz, QuizSubmission
"""
from pydantic import BaseModel
from typing import Optional, Any
from datetime import datetime


class QuizOut(BaseModel):
    id: int
    educator_id: int
    title: str
    description: Optional[str] = None
    pdf_filename: str
    total_questions: int
    status: str
    error_message: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class QuizSubmissionCreate(BaseModel):
    answers_json: Optional[str] = None  # JSON stringifié


class QuizSubmissionOut(BaseModel):
    id: int
    quiz_id: int
    student_id: int
    student_name: str
    score: Optional[float] = None
    max_score: float
    feedback_json: Optional[str] = None
    ai_graded: bool
    submitted_at: datetime
    graded_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class QuizResult(BaseModel):
    """Résultat retourné après soumission et correction Gemini."""
    score: float
    max_score: float
    percentage: float
    feedback: Any  # JSON parsé : liste de dicts par question
