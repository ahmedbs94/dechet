"""
app/collector_routes/models.py — Modèle SQLAlchemy : CollectionRoute
=====================================================================
Tournées de collecte planifiées pour les prestataires (role=collector).
Permet de planifier, démarrer et terminer une tournée sur plusieurs
points de collecte.
"""
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


ROUTE_STATUSES = ("planned", "in_progress", "completed", "cancelled")


class CollectionRoute(Base):
    """Tournée de collecte planifiée pour un prestataire."""
    __tablename__ = "collection_routes"

    id              = Column(Integer, primary_key=True, index=True)
    collector_id    = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Planification
    date_planned    = Column(DateTime, nullable=False, index=True)
    status          = Column(String, default="planned", index=True)  # planned/in_progress/completed/cancelled

    # Points de collecte à visiter (liste d'IDs JSON)
    # ex: [1, 3, 7, 12]
    point_ids       = Column(Text, nullable=True)   # JSON-stringified list

    # Notes du collecteur
    notes           = Column(Text, nullable=True)

    # Résultat de la tournée
    total_weight_kg = Column(String, nullable=True)  # kg total collecté
    completed_at    = Column(DateTime, nullable=True)

    # Timestamps
    created_at      = Column(DateTime, default=datetime.utcnow)
    updated_at      = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relation
    collector = relationship("User", foreign_keys=[collector_id])
