"""
app/users/models.py — Modèle SQLAlchemy : User
"""
from sqlalchemy import Boolean, Column, Integer, String, Float, DateTime
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime
from app.base import Base


def generate_unique_qr_token():
    """Generate a cryptographically unique QR code token.
    Format: ECOREWIND-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    This guarantees global uniqueness (UUID4 = 122 bits of randomness)."""
    return f"ECOREWIND-{uuid.uuid4()}"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    full_name = Column(String)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True, index=True)
    is_verified = Column(Boolean, default=False)
    role = Column(String, default="user", index=True)  # user, admin, educator, intercommunality, pointManager, collector
    google_id = Column(String, unique=True, index=True, nullable=True)
    facebook_id = Column(String, unique=True, index=True, nullable=True)
    qr_code = Column(String, unique=True, index=True, nullable=False, default=generate_unique_qr_token)
    reset_token = Column(String, unique=True, index=True, nullable=True)
    token_expires = Column(String, nullable=True)
    avatar_url = Column(String, nullable=True)  # URL de la photo de profil
    global_score = Column(Float, default=0.0, index=True)  # Score global de l'utilisateur
    created_at = Column(DateTime, default=datetime.utcnow, index=True)  # Date d'inscription
    fcm_token = Column(String, nullable=True)  # Firebase Cloud Messaging token (push notifications mobiles)
    mfa_enabled = Column(Boolean, default=False, nullable=False)  # Authentification forte (TOTP)
    mfa_secret = Column(String, nullable=True)  # Clé TOTP secrète pour MFA

    posts = relationship("Post", back_populates="author")
    saved_posts = relationship("SavedPost", back_populates="user")
    likes = relationship("Like", back_populates="user")
