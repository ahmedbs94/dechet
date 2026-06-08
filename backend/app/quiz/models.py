"""
app/quiz/models.py — Modèles SQLAlchemy : Quiz, QuizSubmission
"""
from sqlalchemy import Boolean, Column, Integer, String, DateTime, Text, Float, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


class Quiz(Base):
    __tablename__ = "quizzes"

    id = Column(Integer, primary_key=True, index=True)
    educator_id = Column(Integer, ForeignKey("users.id"), index=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    pdf_filename = Column(String, nullable=False)           # fichier PDF original
    questions_json = Column(Text, nullable=True)            # Questions extraites par Gemini (JSON)
    answer_key_json = Column(Text, nullable=True)           # Corrigé généré par Gemini (JSON)
    total_questions = Column(Integer, default=0)
    status = Column(String, default="processing")           # processing | ready | error
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    educator = relationship("User")
    submissions = relationship("QuizSubmission", back_populates="quiz")


class QuizSubmission(Base):
    __tablename__ = "quiz_submissions"

    id = Column(Integer, primary_key=True, index=True)
    quiz_id = Column(Integer, ForeignKey("quizzes.id"), index=True)
    student_id = Column(Integer, ForeignKey("users.id"), index=True)
    student_name = Column(String)
    answers_json = Column(Text, nullable=True)              # Réponses de l'étudiant (JSON)
    score = Column(Float, nullable=True, index=True)          # Note sur 10
    max_score = Column(Float, default=10.0)
    feedback_json = Column(Text, nullable=True)
    ai_graded = Column(Boolean, default=False)
    submitted_at = Column(DateTime, default=datetime.utcnow, index=True)
    graded_at = Column(DateTime, nullable=True)

    quiz = relationship("Quiz", back_populates="submissions")
    student = relationship("User")
