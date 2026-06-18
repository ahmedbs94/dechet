"""
app/qr_bins/schemas.py — Schémas Pydantic : SmartBin, BinScan
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# ── Requêtes ──────────────────────────────────────────────────────────────────

class BinScanRequest(BaseModel):
    """Corps de la requête POST /qr/scan-bin."""
    bin_code: str    # Code QR de la poubelle (ex: "BIN-PLASTIQUE-001")
    qr_code: str     # QR code personnel du citoyen
    weight_kg: Optional[float] = None  # Poids si poubelle connectée


class SmartBinCreate(BaseModel):
    bin_code: str
    collection_point_id: Optional[int] = None
    bin_type: str = "general"
    capacity_kg: Optional[float] = None
    status: str = "active"
    location_note: Optional[str] = None


class SmartBinUpdate(BaseModel):
    collection_point_id: Optional[int] = None
    bin_type: Optional[str] = None
    capacity_kg: Optional[float] = None
    status: Optional[str] = None
    location_note: Optional[str] = None


# ── Réponses ──────────────────────────────────────────────────────────────────

class BinScanResponse(BaseModel):
    """Réponse retournée par POST /qr/scan-bin."""
    success: bool
    user_id: Optional[int] = None
    user_name: Optional[str] = None
    bin_code: Optional[str] = None
    bin_type: Optional[str] = None
    collection_point_id: Optional[int] = None
    points_earned: float = 0.0
    score_before: float = 0.0
    score_after: float = 0.0
    firebase_synced: bool = False
    message: str
    action: str = Field("open_top_lid", description="Action matérielle à effectuer")
    error: Optional[str] = None


class SmartBinOut(BaseModel):
    id: int
    bin_code: str
    bin_type: str
    collection_point_id: Optional[int] = None
    capacity_kg: Optional[float] = None
    location_note: Optional[str] = None
    status: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class BinScanOut(BaseModel):
    id: int
    user_id: int
    qr_code: str
    smart_bin_id: Optional[int] = None
    waste_type: str
    weight_kg: Optional[float] = None
    points_earned: float
    score_before: float
    score_after: float
    firebase_synced: bool
    scanned_at: datetime

    class Config:
        from_attributes = True
