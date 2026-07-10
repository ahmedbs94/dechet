"""
app/intercommunality/zone_schemas.py
======================================
Pydantic schemas pour les zones territoriales et affectations de collecteurs.
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, model_validator


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
    # Mode 1 : affectation à une zone existante
    zone_id:             Optional[int]       = None
    # Mode 2 : affectation directe à un ou plusieurs centres de tri (sans zone)
    collection_point_ids: Optional[List[int]] = None
    # Rétro-compat : ancien champ singulier
    collection_point_id: Optional[int]       = None

    collector_id:    Optional[int]      = None
    group_id:        Optional[int]      = None
    mission_message: Optional[str]      = None
    priority:        Optional[str]      = "normal"   # normal | urgent
    due_date:        Optional[datetime] = None

    @model_validator(mode="after")
    def check_target(self) -> "CollectorZoneAssignmentCreate":
        """Au moins une cible doit être fournie."""
        has_target = (
            self.zone_id is not None
            or (self.collection_point_ids and len(self.collection_point_ids) > 0)
            or self.collection_point_id is not None
        )
        if not has_target:
            raise ValueError(
                "Fournir zone_id OU collection_point_ids (liste de centres de tri)"
            )
        return self


class CollectorZoneAssignmentUpdate(BaseModel):
    status:          Optional[str] = None        # pending | in_progress | done | cancelled
    collector_notes: Optional[str] = None
    completed_at:    Optional[datetime] = None


class CollectionPointCoords(BaseModel):
    """Coordonnées d'un centre de tri pour la carte mission."""
    id:      int
    name:    str
    lat:     Optional[str] = None
    lng:     Optional[str] = None
    address: Optional[str] = None
    status:  Optional[str] = None


class CollectorZoneAssignmentOut(BaseModel):
    id:                    int
    zone_id:               Optional[int]  = None
    zone_name:             Optional[str]  = None
    zone_territory:        Optional[str]  = None
    zone_color:            Optional[str]  = None
    # Centres directs (liste JSON)
    collection_point_ids:  Optional[str]  = None   # stocké JSON côté DB
    target_label:          Optional[str]  = None   # ex: "CR Bardo + CR Manouba"
    # Données enrichies pour la carte mission (liste d'objets avec coords)
    collection_points_data: Optional[List[CollectionPointCoords]] = None
    # Rétro-compat : ancien champ singulier
    collection_point_id:   Optional[int]  = None
    collection_point_name: Optional[str]  = None
    collector_id:          Optional[int]  = None
    collector_name:        Optional[str]  = None
    collector_email:       Optional[str]  = None
    group_id:              Optional[int]  = None
    group_name:            Optional[str]  = None
    assigned_by:           int
    assigner_name:         Optional[str]  = None
    mission_message:       Optional[str]  = None
    priority:              str
    status:                str
    due_date:              Optional[datetime] = None
    assigned_at:           datetime
    completed_at:          Optional[datetime] = None
    collector_notes:       Optional[str]  = None

    class Config:
        from_attributes = True
