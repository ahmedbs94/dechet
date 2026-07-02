"""
app/reports/models.py — Modèle SQLAlchemy : CitizenReport
==========================================================
Signalements citoyens sur les anomalies des points de collecte
(fermeture, saturation, dommage, etc.).
Traités par le gestionnaire de points de collecte (pointManager).
"""
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


REPORT_TYPES   = ("closure", "saturation", "damage", "inaccessible", "other")
REPORT_STATUSES = ("pending", "processing", "resolved", "rejected")


class CitizenReport(Base):
    """Signalement citoyen associé à un point de collecte."""
    __tablename__ = "citizen_reports"

    id                   = Column(Integer, primary_key=True, index=True)
    collection_point_id  = Column(Integer, ForeignKey("collection_points.id"), nullable=False, index=True)
    user_id              = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Type d'anomalie signalée
    report_type          = Column(String, nullable=False, default="other")
    # Description libre
    description          = Column(Text, nullable=True)
    # Photo optionnelle (URL vers uploads/)
    photo_url            = Column(String, nullable=True)

    # Traitement par le gestionnaire
    status               = Column(String, default="pending", index=True)  # pending/processing/resolved/rejected
    assigned_to          = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    resolution_note      = Column(Text, nullable=True)
    resolved_at          = Column(DateTime, nullable=True)

    # Timestamps
    created_at           = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at           = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relations
    reporter        = relationship("User",            foreign_keys=[user_id])
    assigned_manager = relationship("User",           foreign_keys=[assigned_to])
    collection_point = relationship("CollectionPoint", foreign_keys=[collection_point_id])
