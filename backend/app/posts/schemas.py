"""
app/posts/schemas.py — Schémas Pydantic : Post, Comment
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class CommentBase(BaseModel):
    user_name: str
    user_avatar_url: Optional[str] = None
    content: str


class CommentCreate(CommentBase):
    parent_id: Optional[int] = None


class CommentOut(CommentBase):
    id: int
    user_id: int
    post_id: int
    parent_id: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


class CommentUpdate(BaseModel):
    content: str


class PostBase(BaseModel):
    user_name: str
    user_avatar_url: str
    image_url: str
    description: str


class PostCreate(PostBase):
    pass


class PostOut(PostBase):
    id: int
    user_id: int
    created_at: datetime
    likes_count: int
    # Statut de modération IA
    status: str = "pending_review"
    # Champs d'audit IA
    moderation_score: float = 0.0
    moderation_reason: Optional[str] = None
    moderated_at: Optional[datetime] = None
    moderation_model_version: Optional[str] = None
    comments: List[CommentOut] = []

    class Config:
        from_attributes = True


class PostUpdate(BaseModel):
    description: Optional[str] = None
    image_url: Optional[str] = None
