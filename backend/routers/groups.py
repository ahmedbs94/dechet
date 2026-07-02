"""
routers/groups.py — Gestion des groupes de citoyens
=====================================================
Endpoints pour l'éducateur :
  POST   /groups                    — Créer un groupe
  GET    /groups/my                 — Mes groupes
  PUT    /groups/{id}               — Modifier un groupe
  DELETE /groups/{id}               — Supprimer un groupe
  GET    /groups/{id}/members       — Liste des membres
  POST   /groups/{id}/members       — Ajouter un citoyen
  DELETE /groups/{id}/members/{uid} — Retirer un citoyen
  GET    /citizens                  — Liste de tous les citoyens (pour le picker)
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload
from typing import Optional

import db_models as db_models
from database import get_db
from core.deps import get_current_user, _utc_iso

router = APIRouter(tags=["groups"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _fmt_group(g: db_models.CitizenGroup) -> dict:
    return {
        "id":          g.id,
        "educator_id": g.educator_id,
        "name":        g.name,
        "description": g.description or "",
        "color":       g.color or "#00C896",
        "created_at":  _utc_iso(g.created_at),
        "member_count": len(g.members),
        "members": [
            {
                "user_id":   m.user_id,
                "user_name": m.user.full_name if m.user else "",
                "email":     m.user.email if m.user else "",
                "avatar_url": m.user.avatar_url if m.user else "",
            }
            for m in g.members
        ],
    }


# ── Schemas ───────────────────────────────────────────────────────────────────

class GroupCreate(BaseModel):
    name:        str
    description: Optional[str] = ""
    color:       Optional[str] = "#00C896"


class GroupUpdate(BaseModel):
    name:        Optional[str] = None
    description: Optional[str] = None
    color:       Optional[str] = None


class AddMemberBody(BaseModel):
    user_id: int


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/citizens")
async def list_citizens(
    q: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Liste tous les citoyens (rôle user) — pour le picker de l'éducateur."""
    if current_user.role not in ("educator", "admin", "superadmin"):
        raise HTTPException(status_code=403, detail="Réservé aux éducateurs")
    query = db.query(db_models.User).filter(db_models.User.role == "user")
    if q:
        query = query.filter(
            db_models.User.full_name.ilike(f"%{q}%") |
            db_models.User.email.ilike(f"%{q}%")
        )
    users = query.order_by(db_models.User.full_name).limit(50).all()
    return [
        {
            "id":         u.id,
            "full_name":  u.full_name,
            "email":      u.email,
            "avatar_url": u.avatar_url or "",
            "global_score": u.global_score,
        }
        for u in users
    ]


@router.post("/groups")
async def create_group(
    body: GroupCreate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    if current_user.role not in ("educator", "admin", "superadmin"):
        raise HTTPException(status_code=403, detail="Réservé aux éducateurs")
    group = db_models.CitizenGroup(
        educator_id=current_user.id,
        name=body.name,
        description=body.description,
        color=body.color or "#00C896",
    )
    db.add(group)
    db.commit()
    db.refresh(group)
    return JSONResponse(content=_fmt_group(group), status_code=201)


@router.get("/groups/my")
async def get_my_groups(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    if current_user.role not in ("educator", "admin", "superadmin"):
        raise HTTPException(status_code=403, detail="Réservé aux éducateurs")
    groups = (
        db.query(db_models.CitizenGroup)
        .options(joinedload(db_models.CitizenGroup.members).joinedload(db_models.GroupMember.user))
        .filter(db_models.CitizenGroup.educator_id == current_user.id)
        .order_by(db_models.CitizenGroup.created_at.desc())
        .all()
    )
    return [_fmt_group(g) for g in groups]


@router.put("/groups/{group_id}")
async def update_group(
    group_id: int,
    body: GroupUpdate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    group = db.query(db_models.CitizenGroup).filter(
        db_models.CitizenGroup.id == group_id
    ).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe non trouvé")
    if group.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")
    if body.name is not None:        group.name        = body.name
    if body.description is not None: group.description = body.description
    if body.color is not None:       group.color       = body.color
    db.commit()
    db.refresh(group)
    return _fmt_group(group)


@router.delete("/groups/{group_id}")
async def delete_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    group = db.query(db_models.CitizenGroup).filter(
        db_models.CitizenGroup.id == group_id
    ).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe non trouvé")
    if group.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")
    db.delete(group)
    db.commit()
    return {"message": "Groupe supprimé"}


@router.post("/groups/{group_id}/members")
async def add_member(
    group_id: int,
    body: AddMemberBody,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    group = db.query(db_models.CitizenGroup).filter(
        db_models.CitizenGroup.id == group_id
    ).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe non trouvé")
    if group.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")
    # Vérifier que le citoyen existe
    user = db.query(db_models.User).filter(db_models.User.id == body.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Citoyen non trouvé")
    # Éviter les doublons
    existing = db.query(db_models.GroupMember).filter(
        db_models.GroupMember.group_id == group_id,
        db_models.GroupMember.user_id == body.user_id,
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Citoyen déjà dans ce groupe")
    db.add(db_models.GroupMember(group_id=group_id, user_id=body.user_id))
    db.commit()
    return {"message": f"{user.full_name} ajouté au groupe"}


@router.delete("/groups/{group_id}/members/{user_id}")
async def remove_member(
    group_id: int,
    user_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    group = db.query(db_models.CitizenGroup).filter(
        db_models.CitizenGroup.id == group_id
    ).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe non trouvé")
    if group.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")
    member = db.query(db_models.GroupMember).filter(
        db_models.GroupMember.group_id == group_id,
        db_models.GroupMember.user_id == user_id,
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="Membre non trouvé")
    db.delete(member)
    db.commit()
    return {"message": "Membre retiré du groupe"}
