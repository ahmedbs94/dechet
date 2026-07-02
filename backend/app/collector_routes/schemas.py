"""
app/collector_routes/schemas.py — Schémas Pydantic : CollectionRoute
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ── Création ──────────────────────────────────────────────────────────────────

class CollectionRouteCreate(BaseModel):
    date_planned:   datetime      = Field(..., description="Date/heure planifiée de la tournée")
    point_ids:      List[int]     = Field(..., description="IDs des points de collecte à visiter")
    notes:          Optional[str] = Field(None, description="Notes pour le collecteur")


# ── Mise à jour ───────────────────────────────────────────────────────────────

class CollectionRouteUpdate(BaseModel):
    date_planned:   Optional[datetime] = None
    point_ids:      Optional[List[int]] = None
    notes:          Optional[str] = None


# ── Complétion ────────────────────────────────────────────────────────────────

class RouteComplete(BaseModel):
    total_weight_kg: Optional[str] = Field(None, description="Poids total collecté en kg")
    notes:           Optional[str] = Field(None, description="Observations de fin de tournée")


# ── Sortie ────────────────────────────────────────────────────────────────────

class CollectionRouteOut(BaseModel):
    id:              int
    collector_id:    int
    collector_name:  Optional[str] = None
    date_planned:    datetime
    status:          str
    point_ids:       Optional[List[int]] = None
    points_details:  Optional[List[dict]] = None  # [{id, name, address, status}]
    notes:           Optional[str] = None
    total_weight_kg: Optional[str] = None
    completed_at:    Optional[datetime] = None
    created_at:      Optional[datetime] = None

    class Config:
        from_attributes = True
