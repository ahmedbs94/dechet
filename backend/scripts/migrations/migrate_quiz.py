"""
Migration: Ajouter les tables Quiz et QuizSubmission
=====================================================
Usage: python migrate_quiz.py
"""
import sys, os
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from database import engine
from sqlalchemy import inspect

inspector = inspect(engine)
existing = inspector.get_table_names()

if "quizzes" in existing and "quiz_submissions" in existing:
    print("[OK] Les tables 'quizzes' et 'quiz_submissions' existent deja.")
else:
    import db_models
    db_models.Base.metadata.create_all(bind=engine)
    print("[OK] Tables 'quizzes' et 'quiz_submissions' creees avec succes.")

# Verification
inspector = inspect(engine)
for table in ["quizzes", "quiz_submissions"]:
    if table in inspector.get_table_names():
        cols = [c["name"] for c in inspector.get_columns(table)]
        print(f"  [{table}] colonnes: {', '.join(cols)}")
    else:
        print(f"  [ERREUR] Table '{table}' introuvable !")
