"""
app/intercommunality/zone_models.py
====================================
Modèles pour la gestion des zones territoriales et
l'affectation des collecteurs (F5 — Pilotage Collecteurs).

Tables :
  - collector_zones          : zones définies par l'intercommunalité
  - collector_zone_assignments : affectation d'un collecteur à une zone
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
from database import Base


class CollectorZone(Base):
    """
    Zone territoriale créée par l'intercommunalité.
    Regroupe un ensemble de points de collecte et de poubelles
    correspondant à un secteur géographique.
    """
    __tablename__ = "collector_zones"

    id          = Column(Integer, primary_key=True, index=True)
    name        = Column(String, nullable=False, index=True)        # ex: "Secteur Nord", "Zone Centre"
    territory   = Column(String, nullable=False, index=True)        # ex: "Grand Tunis", "Ariana"
    description = Column(Text, nullable=True)
    color_hex   = Column(String, default="#4CAF50", nullable=False) # couleur UI de la zone
    created_by  = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at  = Column(DateTime, default=datetime.utcnow)
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    creator     = relationship("User", foreign_keys=[created_by])
    assignments = relationship("CollectorZoneAssignment", back_populates="zone",
                               cascade="all, delete-orphan")


class CollectorZoneAssignment(Base):
    """
    Affectation d'un collecteur ou groupe à une zone ou centre de tri.
    Cycle de vie : pending → in_progress → done | cancelled
    """
    __tablename__ = "collector_zone_assignments"

    id              = Column(Integer, primary_key=True, index=True)
    zone_id         = Column(Integer, ForeignKey("collector_zones.id", ondelete="CASCADE"),
                             nullable=True, index=True)
    collection_point_id = Column(Integer, ForeignKey("collection_points.id", ondelete="CASCADE"),
                                 nullable=True, index=True)
    collector_id    = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    group_id        = Column(Integer, ForeignKey("custom_actor_groups.id", ondelete="CASCADE"),
                             nullable=True, index=True)
    assigned_by     = Column(Integer, ForeignKey("users.id"), nullable=False)

    mission_message      = Column(Text, nullable=True)
    priority             = Column(String, default="normal")  # normal | urgent
    status               = Column(String, default="pending", index=True)
    # pending → in_progress → done | cancelled

    # Affectation directe à plusieurs centres (sans zone)
    # Stockage JSON : "[1, 3, 7]" — liste d'IDs de collection_points
    collection_point_ids = Column(Text, nullable=True)
    # Label lisible automatiquement généré : "CR Bardo + CR Manouba"
    target_label         = Column(String(200), nullable=True)

    due_date        = Column(DateTime, nullable=True)
    assigned_at     = Column(DateTime, default=datetime.utcnow, index=True)
    completed_at    = Column(DateTime, nullable=True)
    collector_notes = Column(Text, nullable=True)  # notes laissées par le collecteur

    zone             = relationship("CollectorZone", back_populates="assignments")
    collection_point = relationship("CollectionPoint")
    collector        = relationship("User", foreign_keys=[collector_id])
    group            = relationship("CustomActorGroup")
    assigner         = relationship("User", foreign_keys=[assigned_by])
