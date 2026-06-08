"""
app/notifications/models.py — Modèle SQLAlchemy : Notification
"""
from sqlalchemy import Boolean, Column, Integer, String, DateTime, ForeignKey
from datetime import datetime
from app.base import Base


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)  # recipient
    type = Column(String)  # like, comment, save
    title = Column(String)
    body = Column(String)
    from_user_name = Column(String)
    post_id = Column(Integer, nullable=True)
    comment_id = Column(Integer, nullable=True)  # ID of the comment that triggered the notification
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
