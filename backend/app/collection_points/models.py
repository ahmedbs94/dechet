"""
app/collection_points/models.py — Modèle SQLAlchemy : CollectionPoint
"""
from sqlalchemy import Boolean, Column, Float, Integer, String, DateTime
from datetime import datetime
from app.base import Base


class CollectionPoint(Base):
    __tablename__ = "collection_points"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    lat = Column(Float, nullable=True)   # latitude WGS84
    lng = Column(Float, nullable=True)   # longitude WGS84
    is_verified = Column(Boolean, default=False)
    types = Column(String, default="")  # Comma-separated: "plastique,verre,papier"
    address = Column(String, nullable=True)
    hours = Column(String, nullable=True)
    status = Column(String, default="disponible")  # disponible, saturé, maintenance
    load_level = Column(Float, default=0.0)  # pourcentage remplissage 0.0–100.0
    created_at = Column(DateTime, default=datetime.utcnow)
