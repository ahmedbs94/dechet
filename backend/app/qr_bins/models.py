"""
app/qr_bins/models.py — Modèles SQLAlchemy : SmartBin, BinScan
"""
from sqlalchemy import Boolean, Column, Integer, String, DateTime, Float, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


class SmartBin(Base):
    """Poubelle intelligente rattachée à un point de collecte.
    Chaque bac a un code QR unique (bin_code) qui est scanné par les citoyens.
    Un point de collecte peut avoir plusieurs bacs (1 par type de déchet).
    """
    __tablename__ = "smart_bins"

    id                  = Column(Integer, primary_key=True, index=True)
    bin_code            = Column(String, unique=True, index=True, nullable=False)
                          # Ex: "BIN-PLASTIC-A3F2", "BIN-VERRE-7C91" …
    collection_point_id = Column(Integer, ForeignKey("collection_points.id"), nullable=True, index=True)
    bin_type            = Column(String, default="general")
                          # plastique | verre | papier | carton | metal
                          # organique | electronique | textile | general
    capacity_kg         = Column(Float, nullable=True)    # Capacité max en kg
    status              = Column(String, default="active")
                          # active | inactive | maintenance | full
    location_note       = Column(String, nullable=True)   # "Côté entrée", "Bâtiment B", …
    created_at          = Column(DateTime, default=datetime.utcnow)

    collection_point    = relationship("CollectionPoint")
    scans               = relationship("BinScan", back_populates="smart_bin")


class BinScan(Base):
    """Historique de tous les scans QR sur les poubelles intelligentes."""
    __tablename__ = "bin_scans"

    id              = Column(Integer, primary_key=True, index=True)
    user_id         = Column(Integer, ForeignKey("users.id"), index=True)
    qr_code         = Column(String, nullable=False)           # QR code citoyen scanné
    smart_bin_id    = Column(Integer, ForeignKey("smart_bins.id"), nullable=True, index=True)
                      # FK vers smart_bins (None si le bin_code n'existe pas encore)
    bin_id          = Column(String, nullable=True)             # LEGACY: bin_code textuel (conservé)
    waste_type      = Column(String, default="general", index=True)   # plastique, verre, papier, …
    weight_kg       = Column(Float, nullable=True)              # Poids en kg
    points_earned   = Column(Float, default=0.0, index=True)          # Points attribués
    score_before    = Column(Float, default=0.0)                # Score avant scan
    score_after     = Column(Float, default=0.0)                # Score après scan
    firebase_synced = Column(Boolean, default=False, index=True)      # True si sync Firebase OK
    scanned_at      = Column(DateTime, default=datetime.utcnow, index=True)

    user        = relationship("User")
    smart_bin   = relationship("SmartBin", back_populates="scans")
