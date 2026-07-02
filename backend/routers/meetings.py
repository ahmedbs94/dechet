"""
routers/meetings.py — Gestion des séances Google Meet
=======================================================
Endpoints pour les éducateurs (créer, modifier, annuler les séances)
et les citoyens (voir leurs invitations, confirmer/décliner).

Génération automatique du lien Google Meet :
  Format : https://meet.google.com/xxx-xxxx-xxx
  (codes aléatoires de 3-4-3 lettres minuscules)
"""

import random
import string
import threading
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

import db_models as db_models
from database import get_db
from core.deps import get_current_user, _utc_iso
from services.email_service import send_meeting_invitation

router = APIRouter(tags=["meetings"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _gen_meet_code() -> str:
    """Génère un code Google Meet aléatoire (format xxx-xxxx-xxx)."""
    def seg(n): return ''.join(random.choices(string.ascii_lowercase, k=n))
    return f"https://meet.google.com/{seg(3)}-{seg(4)}-{seg(3)}"


def _fmt_meeting(m: db_models.Meeting) -> dict:
    return {
        "id":               m.id,
        "educator_id":      m.educator_id,
        "educator_name":    m.educator_name,
        "title":            m.title,
        "description":      m.description or "",
        "meet_link":        m.meet_link,
        "scheduled_at":     _utc_iso(m.scheduled_at),
        "duration_minutes": m.duration_minutes,
        "group_name":       m.group_name or "",
        "audience":         m.audience,
        "status":           m.status,
        "created_at":       _utc_iso(m.created_at),
        "participants_count": len(m.participants),
        "participants": [
            {"user_id": p.user_id, "user_name": p.user_name, "status": p.status}
            for p in m.participants
        ],
    }


def _send_emails_async(
    emails: list, names: list, educator_name: str, title: str,
    description: str, scheduled_at: datetime, duration: int,
    meet_link: str, group_name: str
):
    """Lance l'envoi d'emails dans un thread séparé (non bloquant)."""
    def _task():
        send_meeting_invitation(
            to_emails=emails,
            recipient_names=names,
            educator_name=educator_name,
            course_title=title,
            description=description,
            scheduled_at=scheduled_at,
            duration_minutes=duration,
            meet_link=meet_link,
            group_name=group_name,
        )
    threading.Thread(target=_task, daemon=True, name="email-invite").start()


# ── Pydantic Schemas ──────────────────────────────────────────────────────────

class MeetingCreate(BaseModel):
    title:            str
    description:      Optional[str] = ""
    scheduled_at:     str            # ISO 8601 : "2026-05-10T14:30:00"
    duration_minutes: Optional[int]  = 60
    group_name:       Optional[str]  = ""
    audience:         Optional[str]  = "all"    # "all" | "group"
    citizen_ids:      Optional[List[int]] = []   # IDs manuels
    group_id:         Optional[int]  = None      # ID d'un groupe préexistant


class MeetingUpdate(BaseModel):
    title:            Optional[str]       = None
    description:      Optional[str]       = None
    scheduled_at:     Optional[str]       = None
    duration_minutes: Optional[int]       = None
    group_name:       Optional[str]       = None
    audience:         Optional[str]       = None
    status:           Optional[str]       = None
    citizen_ids:      Optional[List[int]] = None


class ParticipantResponse(BaseModel):
    status: str  # "confirmed" | "declined"


# ── Educator Endpoints ────────────────────────────────────────────────────────

@router.post("/meetings")
async def create_meeting(
    body: MeetingCreate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Créer une nouvelle séance Google Meet (éducateur uniquement)."""
    if current_user.role not in ("educator", "admin", "superadmin"):
        raise HTTPException(status_code=403, detail="Réservé aux éducateurs")

    # Parser la date
    try:
        scheduled_dt = datetime.fromisoformat(body.scheduled_at.replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(status_code=400, detail="Format de date invalide (ISO 8601 attendu)")

    # Résoudre le nom du groupe si group_id fourni
    resolved_group_name = body.group_name or ""
    if body.group_id:
        grp = db.query(db_models.CitizenGroup).options(
            joinedload(db_models.CitizenGroup.members).joinedload(db_models.GroupMember.user)
        ).filter(db_models.CitizenGroup.id == body.group_id).first()
        if grp:
            resolved_group_name = grp.name
            # Fusionner les membres du groupe avec les IDs manuels
            group_citizen_ids = [m.user_id for m in grp.members]
            all_citizen_ids = list(set((body.citizen_ids or []) + group_citizen_ids))
        else:
            all_citizen_ids = body.citizen_ids or []
    else:
        all_citizen_ids = body.citizen_ids or []

    # Créer la séance
    meeting = db_models.Meeting(
        educator_id=current_user.id,
        educator_name=current_user.full_name,
        title=body.title,
        description=body.description,
        meet_link=_gen_meet_code(),
        scheduled_at=scheduled_dt,
        duration_minutes=body.duration_minutes,
        group_name=resolved_group_name,
        audience=body.audience or "all",
        status="scheduled",
    )
    db.add(meeting)
    db.flush()

    # Collecter les participants et leurs emails pour l'envoi
    invite_emails: list = []
    invite_names:  list = []

    if body.audience == "group" and all_citizen_ids:
        target_users = db.query(db_models.User).filter(
            db_models.User.id.in_(all_citizen_ids)
        ).all()
    else:
        # audience == "all"
        target_users = db.query(db_models.User).filter(
            db_models.User.role == "user"
        ).all()

    for user in target_users:
        db.add(db_models.MeetingParticipant(
            meeting_id=meeting.id,
            user_id=user.id,
            user_name=user.full_name,
            status="invited",
        ))
        db.add(db_models.Notification(
            user_id=user.id,
            type="meeting",
            title=f"📅 Nouvelle séance : {body.title}",
            body=(
                f"{current_user.full_name} vous invite à une séance le "
                f"{scheduled_dt.strftime('%d/%m/%Y à %H:%M')}. "
                f"Durée : {body.duration_minutes} min."
            ),
            from_user_name=current_user.full_name,
        ))
        invite_emails.append(user.email)
        invite_names.append(user.full_name)

    db.commit()
    db.refresh(meeting)

    # Envoyer les emails Gmail en arrière-plan (non bloquant)
    if invite_emails:
        _send_emails_async(
            emails=invite_emails,
            names=invite_names,
            educator_name=current_user.full_name,
            title=body.title,
            description=body.description or "",
            scheduled_at=scheduled_dt,
            duration=body.duration_minutes or 60,
            meet_link=meeting.meet_link,
            group_name=resolved_group_name,
        )

    return JSONResponse(content=_fmt_meeting(meeting), status_code=201)


@router.get("/meetings/my")
async def get_my_meetings_educator(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Liste des séances créées par l'éducateur connecté."""
    if current_user.role not in ("educator", "admin", "superadmin"):
        raise HTTPException(status_code=403, detail="Réservé aux éducateurs")
    meetings = (
        db.query(db_models.Meeting)
        .options(joinedload(db_models.Meeting.participants))
        .filter(db_models.Meeting.educator_id == current_user.id)
        .order_by(db_models.Meeting.scheduled_at.desc())
        .all()
    )
    return [_fmt_meeting(m) for m in meetings]


@router.put("/meetings/{meeting_id}")
async def update_meeting(
    meeting_id: int,
    body: MeetingUpdate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Modifier une séance (éducateur propriétaire ou admin)."""
    meeting = db.query(db_models.Meeting).options(
        joinedload(db_models.Meeting.participants)
    ).filter(db_models.Meeting.id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Séance non trouvée")
    if meeting.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")

    if body.title is not None:            meeting.title            = body.title
    if body.description is not None:      meeting.description      = body.description
    if body.duration_minutes is not None: meeting.duration_minutes = body.duration_minutes
    if body.group_name is not None:       meeting.group_name       = body.group_name
    if body.audience is not None:         meeting.audience         = body.audience
    if body.status is not None:           meeting.status           = body.status

    if body.scheduled_at is not None:
        try:
            meeting.scheduled_at = datetime.fromisoformat(
                body.scheduled_at.replace("Z", "+00:00")
            )
        except ValueError:
            raise HTTPException(status_code=400, detail="Format de date invalide")

    # Mettre à jour la liste des participants si fournie
    if body.citizen_ids is not None and body.audience == "group":
        # Supprimer les anciens
        db.query(db_models.MeetingParticipant).filter(
            db_models.MeetingParticipant.meeting_id == meeting_id
        ).delete()
        for uid in body.citizen_ids:
            user = db.query(db_models.User).filter(db_models.User.id == uid).first()
            if user:
                db.add(db_models.MeetingParticipant(
                    meeting_id=meeting_id,
                    user_id=uid,
                    user_name=user.full_name,
                    status="invited",
                ))

    db.commit()
    db.refresh(meeting)
    return _fmt_meeting(meeting)


@router.delete("/meetings/{meeting_id}")
async def delete_meeting(
    meeting_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Supprimer / annuler une séance."""
    meeting = db.query(db_models.Meeting).filter(
        db_models.Meeting.id == meeting_id
    ).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Séance non trouvée")
    if meeting.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")
    db.delete(meeting)
    db.commit()
    return {"message": "Séance supprimée"}


# ── Citizen Endpoints ─────────────────────────────────────────────────────────

@router.get("/meetings/upcoming")
async def get_upcoming_meetings(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Liste des séances à venir pour le citoyen connecté."""
    now = datetime.utcnow()
    # Séances où le citoyen est participant
    participations = (
        db.query(db_models.MeetingParticipant)
        .filter(db_models.MeetingParticipant.user_id == current_user.id)
        .all()
    )
    meeting_ids = [p.meeting_id for p in participations]
    meetings = (
        db.query(db_models.Meeting)
        .options(joinedload(db_models.Meeting.participants))
        .filter(
            db_models.Meeting.id.in_(meeting_ids),
            db_models.Meeting.scheduled_at >= now,
            db_models.Meeting.status != "cancelled",
        )
        .order_by(db_models.Meeting.scheduled_at.asc())
        .all()
    )
    result = []
    for m in meetings:
        data = _fmt_meeting(m)
        # Ajouter le statut de participation du citoyen
        my_p = next((p for p in m.participants if p.user_id == current_user.id), None)
        data["my_status"] = my_p.status if my_p else "invited"
        result.append(data)
    return result


@router.post("/meetings/{meeting_id}/respond")
async def respond_to_meeting(
    meeting_id: int,
    body: ParticipantResponse,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Citoyen confirme ou décline sa participation."""
    participant = db.query(db_models.MeetingParticipant).filter(
        db_models.MeetingParticipant.meeting_id == meeting_id,
        db_models.MeetingParticipant.user_id == current_user.id,
    ).first()
    if not participant:
        raise HTTPException(status_code=404, detail="Invitation non trouvée")
    if body.status not in ("confirmed", "declined"):
        raise HTTPException(status_code=400, detail="Statut invalide (confirmed|declined)")
    participant.status = body.status
    db.commit()
    return {"message": "Réponse enregistrée", "status": body.status}


@router.get("/meetings/all")
async def get_all_meetings(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Admin : voir toutes les séances."""
    if current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Réservé aux admins")
    meetings = (
        db.query(db_models.Meeting)
        .options(joinedload(db_models.Meeting.participants))
        .order_by(db_models.Meeting.scheduled_at.desc())
        .all()
    )
    return [_fmt_meeting(m) for m in meetings]
