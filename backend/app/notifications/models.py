"""
app/notifications/models.py — Modèle SQLAlchemy : Notification
"""
from sqlalchemy import Boolean, Column, Integer, String, DateTime, ForeignKey, Text
from datetime import datetime
from app.base import Base


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)  # recipient
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)  # sender (for replies)
    type = Column(String)  # like, comment, save, intercommunality_message, actor_reply…
    title = Column(String)
    body = Column(Text)
    from_user_name = Column(String)
    post_id = Column(Integer, nullable=True)
    comment_id = Column(Integer, nullable=True)  # ID of the comment that triggered the notification
    source_notification_id = Column(Integer, ForeignKey("notifications.id", ondelete="SET NULL"), nullable=True)  # original message being replied to
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
