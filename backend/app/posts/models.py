"""
app/posts/models.py — Modèles SQLAlchemy : Post, SavedPost, Like, Comment
"""
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Text, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


class Post(Base):
    __tablename__ = "posts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    user_name = Column(String)
    user_avatar_url = Column(String)
    image_url = Column(String)
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    likes_count = Column(Integer, default=0)
    # ── Modération IA ──────────────────────────────────────────────────────────
    # Flux réel : pending_review → published | pending_review (admin) | rejected
    # Les posts sont créés en 'pending_review' puis traités par BackgroundTask.
    # 'pending_ai' n'est PAS utilisé dans ce projet.
    status = Column(
        String,
        default="pending_review",
        nullable=False,
        index=True,           # index pour COUNT GROUP BY status
    )
    moderation_score = Column(Float, default=0.0, nullable=False)
    moderation_reason = Column(String, nullable=True)
    moderation_details = Column(Text, nullable=True)
    moderated_at = Column(DateTime, nullable=True)
    moderation_model_version = Column(String, nullable=True)

    author = relationship("User", back_populates="posts")
    savers = relationship("SavedPost", back_populates="post")
    liked_by = relationship("Like", back_populates="post")
    comments = relationship("Comment", back_populates="post")


class SavedPost(Base):
    __tablename__ = "saved_posts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    post_id = Column(Integer, ForeignKey("posts.id"))
    saved_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="saved_posts")
    post = relationship("Post", back_populates="savers")


class Like(Base):
    __tablename__ = "likes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    post_id = Column(Integer, ForeignKey("posts.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="likes")
    post = relationship("Post", back_populates="liked_by")


class Comment(Base):
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(Integer, ForeignKey("posts.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    user_name = Column(String)
    user_avatar_url = Column(String, nullable=True)
    content = Column(Text)
    parent_id = Column(Integer, ForeignKey("comments.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    post = relationship("Post", back_populates="comments")
    replies = relationship("Comment", backref="parent", remote_side=[id], lazy="joined")
