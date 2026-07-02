"""
app/intercommunality/zone_schemas.py
======================================
Pydantic schemas pour les zones territoriales et affectations de collecteurs.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


# ── Zones ─────────────────────────────────────────────────────────────────────

class CollectorZoneCreate(BaseModel):
    name:        str = Field(..., min_length=2, max_length=100)
    territory:   str = Field(..., min_length=2, max_length=100)
    description: Optional[str] = None
    color_hex:   Optional[str] = "#4CAF50"


class CollectorZoneUpdate(BaseModel):
    name:        Optional[str] = None
    territory:   Optional[str] = None
    description: Optional[str] = None
    color_hex:   Optional[str] = None


class CollectorZoneOut(BaseModel):
    id:          int
    name:        str
    territory:   str
    description: Optional[str]
    color_hex:   str
    created_by:  Optional[int]
    created_at:  datetime
    updated_at:  datetime
    # Enrichi par l'endpoint
    active_assignments: Optional[int] = 0

    class Config:
        from_attributes = True


# ── Assignments ───────────────────────────────────────────────────────────────

class CollectorZoneAssignmentCreate(BaseModel):
    zone_id:         int
    collector_id:    int
    mission_message: Optional[str] = None
    priority:        Optional[str] = "normal"   # normal | urgent
    due_date:        Optional[datetime] = None


class CollectorZoneAssignmentUpdate(BaseModel):
    status:          Optional[str] = None        # pending | in_progress | done | cancelled
    collector_notes: Optional[str] = None
    completed_at:    Optional[datetime] = None


class CollectorZoneAssignmentOut(BaseModel):
    id:              int
    zone_id:         int
    zone_name:       Optional[str] = None
    zone_territory:  Optional[str] = None
    zone_color:      Optional[str] = None
    collector_id:    int
    collector_name:  Optional[str] = None
    collector_email: Optional[str] = None
    assigned_by:     int
    assigner_name:   Optional[str] = None
    mission_message: Optional[str]
    priority:        str
    status:          str
    due_date:        Optional[datetime]
    assigned_at:     datetime
    completed_at:    Optional[datetime]
    collector_notes: Optional[str]

    class Config:
        from_attributes = True
