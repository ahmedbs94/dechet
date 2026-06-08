# app/base.py — Re-exports the single SQLAlchemy Base from database.py
# All app/*/models.py import Base from here to guarantee one shared metadata.
from database import Base

__all__ = ["Base"]
