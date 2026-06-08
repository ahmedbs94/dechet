"""
app/notifications/schemas.py — Schémas Pydantic : Notification
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class NotificationOut(BaseModel):
    id: int
    user_id: int
    type: str
    title: str
    body: str
    from_user_name: Optional[str] = None
    post_id: Optional[int] = None
    comment_id: Optional[int] = None
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True
