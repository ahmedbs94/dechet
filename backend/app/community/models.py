"""
app/community/models.py — Modèles SQLAlchemy : Testimonial, CenterProposal
"""
from sqlalchemy import Boolean, Column, Integer, String, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


class Testimonial(Base):
    __tablename__ = "testimonials"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    user_name = Column(String, nullable=False)
    user_avatar_url = Column(String, nullable=True)
    content = Column(Text, nullable=False)
    rating = Column(Integer, default=5)  # 1-5 stars
    is_approved = Column(Boolean, default=False)  # Admin must approve
    is_featured = Column(Boolean, default=False)  # Featured on landing page
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")


class CenterProposal(Base):
    __tablename__ = "center_proposals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    user_name = Column(String)
    name = Column(String)
    address = Column(String)
    lat = Column(String, nullable=True)
    lng = Column(String, nullable=True)
    waste_types = Column(String, default="")
    description = Column(Text, nullable=True)
    status = Column(String, default="pending")  # pending, approved, rejected
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")
