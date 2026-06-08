"""
app/auth/models.py — Modèle SQLAlchemy : OTPCode
"""
from sqlalchemy import Boolean, Column, Integer, String, DateTime
from datetime import datetime
from app.base import Base


class OTPCode(Base):
    __tablename__ = "otp_codes"

    id = Column(Integer, primary_key=True, index=True)
    identifier = Column(String, index=True)  # email or phone
    code = Column(String)
    purpose = Column(String, default="register")  # register, reset
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime)
    is_used = Column(Boolean, default=False)
