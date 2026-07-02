"""
app/intercommunality/models.py — Modèle SQLAlchemy : LocalInstruction
======================================================================
Consignes locales de tri définies par l'intercommunalité pour son territoire.
"""
from sqlalchemy import Boolean, Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


class LocalInstruction(Base):
    """Consigne locale de tri par type de déchet et territoire."""
    __tablename__ = "local_instructions"

    id            = Column(Integer, primary_key=True, index=True)
    territory     = Column(String, nullable=False, index=True)   # ex: "Grand Tunis"
    city          = Column(String, nullable=True, index=True)    # ex: "Ariana"
    waste_type    = Column(String, nullable=False)               # ex: "Plastique"
    title         = Column(String, nullable=False)               # ex: "Comment trier le plastique"
    instruction   = Column(Text,   nullable=False)               # Corps de la consigne
    is_active     = Column(Boolean, default=True, index=True)
    created_by    = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at    = Column(DateTime, default=datetime.utcnow)
    updated_at    = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    author = relationship("User", foreign_keys=[created_by])


class CustomActorGroup(Base):
    """Groupe d'acteurs locaux créé sur-mesure par l'intercommunalité."""
    __tablename__ = "custom_actor_groups"

    id          = Column(Integer, primary_key=True, index=True)
    name        = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    member_ids  = Column(JSON, nullable=False)                     # Liste d'IDs utilisateurs en format JSON array
    created_by  = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at  = Column(DateTime, default=datetime.utcnow)

    creator = relationship("User", foreign_keys=[created_by])
