"""
app/reports/schemas.py — Schémas Pydantic : CitizenReport
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ── Création (citoyen) ────────────────────────────────────────────────────────

class CitizenReportCreate(BaseModel):
    collection_point_id: int  = Field(..., description="ID du point de collecte concerné")
    report_type:         str  = Field("other", description="Type : closure/saturation/damage/inaccessible/other")
    description:         Optional[str] = Field(None, description="Description libre de l'anomalie")
    photo_url:           Optional[str] = Field(None, description="URL photo (upload préalable)")


# ── Assignation (gestionnaire) ────────────────────────────────────────────────

class ReportAssign(BaseModel):
    assigned_to: int = Field(..., description="ID du gestionnaire qui prend en charge")


# ── Résolution / rejet ────────────────────────────────────────────────────────

class ReportResolve(BaseModel):
    resolution_note: Optional[str] = Field(None, description="Note de résolution")


class ReportReject(BaseModel):
    resolution_note: Optional[str] = Field(None, description="Motif du rejet")


# ── Sortie ────────────────────────────────────────────────────────────────────

class CitizenReportOut(BaseModel):
    id:                   int
    collection_point_id:  int
    collection_point_name: Optional[str] = None
    user_id:              int
    reporter_name:        Optional[str] = None
    report_type:          str
    description:          Optional[str] = None
    photo_url:            Optional[str] = None
    status:               str
    assigned_to:          Optional[int] = None
    assigned_manager_name: Optional[str] = None
    resolution_note:      Optional[str] = None
    resolved_at:          Optional[datetime] = None
    created_at:           Optional[datetime] = None
    updated_at:           Optional[datetime] = None

    class Config:
        from_attributes = True
