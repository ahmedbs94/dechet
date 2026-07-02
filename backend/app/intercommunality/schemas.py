"""
app/intercommunality/schemas.py — Schémas Pydantic : LocalInstruction + CustomActorGroup
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class LocalInstructionBase(BaseModel):
    territory:   str = Field(..., description="Nom du territoire / intercommunalité")
    city:        Optional[str] = Field(None, description="Ville concernée (facultatif)")
    waste_type:  str = Field(..., description="Type de déchet (Plastique, Verre…)")
    title:       str = Field(..., description="Titre court de la consigne")
    instruction: str = Field(..., description="Texte complet de la consigne")
    is_active:   bool = True


class LocalInstructionCreate(LocalInstructionBase):
    pass


class LocalInstructionUpdate(BaseModel):
    territory:   Optional[str] = None
    city:        Optional[str] = None
    waste_type:  Optional[str] = None
    title:       Optional[str] = None
    instruction: Optional[str] = None
    is_active:   Optional[bool] = None


class LocalInstructionOut(LocalInstructionBase):
    id:         int
    created_by: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ── Groupes d'acteurs sur-mesure ──────────────────────────────────────────────

class CustomActorGroupCreate(BaseModel):
    name:        str = Field(..., description="Nom du groupe (ex : Équipe Nord-Tunis)")
    description: Optional[str] = Field(None, description="Description facultative du groupe")
    member_ids:  List[int] = Field(..., description="Liste des IDs des acteurs membres du groupe")


class CustomActorGroupOut(BaseModel):
    id:          int
    name:        str
    description: Optional[str] = None
    member_ids:  List[int]
    created_by:  int
    created_at:  Optional[datetime] = None

    class Config:
        from_attributes = True


# ── Envoi de message ──────────────────────────────────────────────────────────

class ActorNotifyRequest(BaseModel):
    title:   str = Field(..., description="Titre de la notification")
    message: str = Field(..., description="Corps du message")


class GroupNotifyRequest(ActorNotifyRequest):
    pass

