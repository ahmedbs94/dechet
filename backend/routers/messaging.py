"""
routers/messaging.py — API de messagerie inter-rôles EcoRewind
===============================================================

Matrice des conversations autorisées :
  admin/superadmin  → intercommunality, collector, pointManager, educator
  intercommunality  → admin, collector (individuel ou groupe), pointManager
  collector         → admin, intercommunality, pointManager
  pointManager      → admin, intercommunality, collector
  educator          → admin, citoyen individuel, groupe de citoyens
  user (citoyen)    → educator uniquement

Endpoints :
  GET  /messages/eligible-recipients          → utilisateurs à qui on peut écrire
  GET  /messages/groups                       → groupes accessibles (citoyen/collecteur)
  POST /messages                              → envoyer un message (1-à-1)
  POST /messages/group                        → envoyer à un groupe de citoyens
  POST /messages/broadcast                    → broadcast à plusieurs collecteurs
  GET  /messages/conversations                → liste des conversations
  GET  /messages/conversation/{user_id}       → messages 1-à-1 avec un utilisateur
  GET  /messages/group-conversation/{group_id}→ messages d'un groupe
  GET  /messages/broadcast-thread/{msg_id}    → thread d'un broadcast
  POST /messages/{message_id}/reply           → répondre à un message
  PUT  /messages/{message_id}/read            → marquer comme lu
  GET  /messages/unread-count                 → nombre de messages non lus
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

import db_models as db_models
from database import get_db
from core.deps import get_current_user, _utc_iso

router = APIRouter(prefix="/messages", tags=["messaging"])

# ──────────────────────────────────────────────────────────────────────────────
# Matrice des rôles autorisés
# ──────────────────────────────────────────────────────────────────────────────

ALLOWED_TARGETS: dict[str, list[str]] = {
    "admin":            ["intercommunality", "collector", "pointManager", "educator", "educateur", "admin", "superadmin", "user"],
    "superadmin":       ["intercommunality", "collector", "pointManager", "educator", "educateur", "admin", "superadmin", "user"],
    "intercommunality": ["admin", "superadmin", "collector", "pointManager"],
    "collector":        ["admin", "superadmin", "intercommunality", "pointManager"],
    "pointManager":     ["admin", "superadmin", "intercommunality", "collector"],
    "educator":         ["admin", "superadmin", "user"],
    "educateur":        ["admin", "superadmin", "user"],   # variante française
    "user":             ["educator", "educateur"],
}


def _normalize_role(role: str) -> str:
    """Normalise les variantes de rôle (ex: 'educateur' → 'educator')."""
    _map = {
        "educateur": "educator",
        "point_manager": "pointManager",
        "point manager": "pointManager",
    }
    return _map.get(role.lower().strip(), role)


def _check_can_message(sender_role: str, target_role: str):
    s_role = _normalize_role(sender_role)
    t_role = _normalize_role(target_role)
    allowed = ALLOWED_TARGETS.get(s_role, [])
    # Vérifier aussi la version normalisée du target
    if t_role not in allowed and target_role not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Le rôle '{sender_role}' ne peut pas envoyer de message au rôle '{target_role}'",
        )


# ──────────────────────────────────────────────────────────────────────────────
# Schémas Pydantic
# ──────────────────────────────────────────────────────────────────────────────

class SendMessageIn(BaseModel):
    receiver_id: int
    content: str
    parent_id: Optional[int] = None


class SendGroupMessageIn(BaseModel):
    group_id: int          # citizen_group id
    content: str
    parent_id: Optional[int] = None


class BroadcastMessageIn(BaseModel):
    receiver_ids: List[int]           # IDs des collecteurs destinataires
    content: str
    collector_group_label: Optional[str] = None
    parent_id: Optional[int] = None


class ReplyMessageIn(BaseModel):
    content: str


# ──────────────────────────────────────────────────────────────────────────────
# Helpers de sérialisation
# ──────────────────────────────────────────────────────────────────────────────

def _serialize_message(m: db_models.Message, current_user_id: int) -> dict:
    parent_preview = None
    if m.parent:
        parent_preview = {
            "id": m.parent.id,
            "content": m.parent.content[:80],
            "sender_name": m.parent.sender.full_name if m.parent.sender else "?",
        }
    return {
        "id": m.id,
        "sender_id": m.sender_id,
        "sender_name": m.sender.full_name if m.sender else "?",
        "sender_role": m.sender.role if m.sender else "?",
        "sender_avatar": m.sender.avatar_url if m.sender else None,
        "receiver_id": m.receiver_id,
        "receiver_name": m.receiver.full_name if m.receiver else None,
        "group_id": m.group_id,
        "is_group_broadcast": m.is_group_broadcast,
        "collector_group_label": m.collector_group_label,
        "content": m.content,
        "parent_id": m.parent_id,
        "parent_preview": parent_preview,
        "is_read": m.is_read,
        "is_mine": m.sender_id == current_user_id,
        "created_at": _utc_iso(m.created_at),
    }


# ──────────────────────────────────────────────────────────────────────────────
# GET /messages/eligible-recipients
# ──────────────────────────────────────────────────────────────────────────────

@router.get("/eligible-recipients")
async def get_eligible_recipients(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Retourne les utilisateurs à qui l'utilisateur courant peut envoyer un message."""
    my_role = _normalize_role(current_user.role or "")
    allowed_roles = ALLOWED_TARGETS.get(my_role, [])
    if not allowed_roles:
        return []

    users = (
        db.query(db_models.User)
        .filter(
            db_models.User.role.in_(allowed_roles),
            db_models.User.id != current_user.id,
            db_models.User.is_active.isnot(False),   # ✅ compatible SQLite + PostgreSQL
        )
        .order_by(db_models.User.role, db_models.User.full_name)
        .all()
    )
    return [
        {
            "id": u.id,
            "full_name": u.full_name or u.email,
            "email": u.email,
            "role": u.role,
            "avatar_url": getattr(u, "avatar_url", None),
        }
        for u in users
    ]


# ──────────────────────────────────────────────────────────────────────────────
# GET /messages/groups
# ──────────────────────────────────────────────────────────────────────────────

@router.get("/groups")
async def get_accessible_groups(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Retourne les groupes accessibles :
    - Éducateur : ses propres groupes de citoyens
    - Intercommunalité : pas de groupes fixes (broadcast libre sur collecteurs sélectionnés)
    - Autres : liste vide
    """
    if current_user.role == "educator":
        groups = (
            db.query(db_models.CitizenGroup)
            .filter(db_models.CitizenGroup.educator_id == current_user.id)
            .all()
        )
        return [
            {
                "id": g.id,
                "name": g.name,
                "description": g.description,
                "color": g.color,
                "member_count": len(g.members),
                "type": "citizen_group",
            }
            for g in groups
        ]
    return []


# ──────────────────────────────────────────────────────────────────────────────
# POST /messages — Message 1-à-1
# ──────────────────────────────────────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED)
async def send_message(
    payload: SendMessageIn,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    receiver = db.query(db_models.User).filter(db_models.User.id == payload.receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Destinataire introuvable")

    _check_can_message(current_user.role, receiver.role)

    msg = db_models.Message(
        sender_id=current_user.id,
        receiver_id=payload.receiver_id,
        content=payload.content,
        parent_id=payload.parent_id,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)

    # ── Push FCM au destinataire ──────────────────────────────────────────────
    try:
        from services.fcm_push_service import send_push_to_user as _fcm
        sender_name = current_user.full_name or "Quelqu'un"
        _fcm(
            db,
            payload.receiver_id,
            title=sender_name,
            body=payload.content[:120],
            data={
                "type": "message",
                "sender_id": str(current_user.id),
                "sender_name": sender_name,
                "partner_id": str(current_user.id),
            },
        )
    except Exception:
        pass  # Push non bloquant

    return _serialize_message(msg, current_user.id)


# ──────────────────────────────────────────────────────────────────────────────
# POST /messages/group — Message à un groupe de citoyens (éducateur)
# ──────────────────────────────────────────────────────────────────────────────

@router.post("/group", status_code=status.HTTP_201_CREATED)
async def send_group_message(
    payload: SendGroupMessageIn,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    my_role = _normalize_role(current_user.role or "")
    if my_role not in ["educator", "admin", "superadmin"]:
        raise HTTPException(status_code=403,
                            detail="Seuls les éducateurs/admins peuvent envoyer à un groupe")

    group = db.query(db_models.CitizenGroup).filter(db_models.CitizenGroup.id == payload.group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")

    # Créer le message principal (sans receiver_id)
    msg = db_models.Message(
        sender_id=current_user.id,
        group_id=payload.group_id,
        is_group_broadcast=True,
        content=payload.content,
        parent_id=payload.parent_id,
    )
    db.add(msg)
    db.flush()

    # Créer un recipient pour chaque membre du groupe
    for member in group.members:
        recipient = db_models.MessageGroupRecipient(
            message_id=msg.id,
            user_id=member.user_id,
            is_read=False,
        )
        db.add(recipient)

    db.commit()
    db.refresh(msg)

    # ── Push FCM à chaque membre du groupe ───────────────────────────────────
    try:
        from services.fcm_push_service import send_push_to_user as _fcm
        sender_name = current_user.full_name or "Quelqu'un"
        for member in group.members:
            _fcm(
                db,
                member.user_id,
                title=f"{sender_name} ({group.name})",
                body=payload.content[:120],
                data={
                    "type": "group_message",
                    "sender_id": str(current_user.id),
                    "sender_name": sender_name,
                    "group_id": str(group.id),
                    "group_name": group.name,
                },
            )
    except Exception:
        pass  # Push non bloquant

    return {
        **_serialize_message(msg, current_user.id),
        "group_name": group.name,
        "recipients_count": len(group.members),
    }


# ──────────────────────────────────────────────────────────────────────────────
# POST /messages/broadcast — Broadcast collecteurs (intercommunalité)
# ──────────────────────────────────────────────────────────────────────────────

@router.post("/broadcast", status_code=status.HTTP_201_CREATED)
async def broadcast_to_collectors(
    payload: BroadcastMessageIn,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    my_role = _normalize_role(current_user.role or "")
    if my_role not in ["intercommunality", "admin", "superadmin"]:
        raise HTTPException(
            status_code=403,
            detail="Seule l'intercommunalité peut broadcaster aux collecteurs",
        )

    # Vérifier que tous les destinataires sont bien des collecteurs
    receivers = db.query(db_models.User).filter(db_models.User.id.in_(payload.receiver_ids)).all()
    for r in receivers:
        if r.role not in ["collector", "admin", "superadmin"]:
            raise HTTPException(
                status_code=403,
                detail=f"L'utilisateur {r.full_name} n'est pas un collecteur",
            )

    msg = db_models.Message(
        sender_id=current_user.id,
        is_group_broadcast=True,
        collector_group_label=payload.collector_group_label,
        content=payload.content,
        parent_id=payload.parent_id,
    )
    db.add(msg)
    db.flush()

    for r in receivers:
        recipient = db_models.MessageGroupRecipient(
            message_id=msg.id,
            user_id=r.id,
            is_read=False,
        )
        db.add(recipient)

    db.commit()
    db.refresh(msg)

    # ── Push FCM à chaque collecteur broadcasté ───────────────────────────────
    try:
        from services.fcm_push_service import send_push_to_user as _fcm
        sender_name = current_user.full_name or "Intercommunalité"
        for r in receivers:
            _fcm(
                db,
                r.id,
                title=sender_name,
                body=payload.content[:120],
                data={
                    "type": "message",
                    "sender_id": str(current_user.id),
                    "sender_name": sender_name,
                    "partner_id": str(current_user.id),
                },
            )
    except Exception:
        pass  # Push non bloquant

    return {
        **_serialize_message(msg, current_user.id),
        "recipients_count": len(receivers),
    }


# ──────────────────────────────────────────────────────────────────────────────
# GET /messages/unread-count
# ──────────────────────────────────────────────────────────────────────────────

@router.get("/unread-count")
async def unread_count(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    # Messages 1-à-1 non lus
    direct_count = (
        db.query(db_models.Message)
        .filter(
            db_models.Message.receiver_id == current_user.id,
            db_models.Message.is_read == False,
            db_models.Message.is_group_broadcast == False,
        )
        .count()
    )
    # Messages de groupe non lus
    group_count = (
        db.query(db_models.MessageGroupRecipient)
        .filter(
            db_models.MessageGroupRecipient.user_id == current_user.id,
            db_models.MessageGroupRecipient.is_read == False,
        )
        .count()
    )
    return {"count": direct_count + group_count}


# ──────────────────────────────────────────────────────────────────────────────
# GET /messages/conversations
# ──────────────────────────────────────────────────────────────────────────────

@router.get("/conversations")
async def get_conversations(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Retourne la liste des conversations de l'utilisateur courant :
    - Conversations 1-à-1 (derniers messages par interlocuteur)
    - Conversations de groupe (citizen_group ou broadcast collecteurs)
    """
    conversations = []
    seen_direct_partners: set[int] = set()  # pour dédupliquer direct + broadcast individuel

    # ── 1. Conversations 1-à-1 (directs + broadcasts individuels) ─────────────
    # Collecte tous les interlocuteurs : messages directs ET broadcasts
    # avec receiver_id défini (ex: Mairie → Collecteur via /broadcast)
    sent_to_direct = (
        db.query(db_models.Message.receiver_id.label("partner_id"))
        .filter(
            db_models.Message.sender_id == current_user.id,
            db_models.Message.receiver_id.isnot(None),
            db_models.Message.is_group_broadcast == False,
        )
        .distinct()
    )
    # Broadcasts envoyés à un receiver_id spécifique (intercommunality → collector individuel)
    sent_to_broadcast_individual = (
        db.query(db_models.Message.receiver_id.label("partner_id"))
        .filter(
            db_models.Message.sender_id == current_user.id,
            db_models.Message.receiver_id.isnot(None),
            db_models.Message.is_group_broadcast == True,
            db_models.Message.group_id.is_(None),
        )
        .distinct()
    )
    received_from_direct = (
        db.query(db_models.Message.sender_id.label("partner_id"))
        .filter(
            db_models.Message.receiver_id == current_user.id,
            db_models.Message.is_group_broadcast == False,
        )
        .distinct()
    )
    # Messages reçus en broadcast individuel (collecteur reçoit de intercommunality)
    received_from_broadcast_individual = (
        db.query(db_models.Message.sender_id.label("partner_id"))
        .filter(
            db_models.Message.receiver_id == current_user.id,
            db_models.Message.is_group_broadcast == True,
            db_models.Message.group_id.is_(None),
        )
        .distinct()
    )

    partner_ids = set()
    for row in sent_to_direct.all():
        partner_ids.add(row.partner_id)
    for row in sent_to_broadcast_individual.all():
        partner_ids.add(row.partner_id)
    for row in received_from_direct.all():
        partner_ids.add(row.partner_id)
    for row in received_from_broadcast_individual.all():
        partner_ids.add(row.partner_id)

    for pid in partner_ids:
        # Dernier message (direct OU broadcast individuel) de cette conversation
        last_msg = (
            db.query(db_models.Message)
            .filter(
                or_(
                    # Messages directs
                    and_(
                        db_models.Message.sender_id == current_user.id,
                        db_models.Message.receiver_id == pid,
                        db_models.Message.is_group_broadcast == False,
                    ),
                    and_(
                        db_models.Message.sender_id == pid,
                        db_models.Message.receiver_id == current_user.id,
                        db_models.Message.is_group_broadcast == False,
                    ),
                    # Broadcasts individuels (receiver_id défini, group_id absent)
                    and_(
                        db_models.Message.sender_id == current_user.id,
                        db_models.Message.receiver_id == pid,
                        db_models.Message.is_group_broadcast == True,
                        db_models.Message.group_id.is_(None),
                    ),
                    and_(
                        db_models.Message.sender_id == pid,
                        db_models.Message.receiver_id == current_user.id,
                        db_models.Message.is_group_broadcast == True,
                        db_models.Message.group_id.is_(None),
                    ),
                )
            )
            .order_by(db_models.Message.created_at.desc())
            .first()
        )
        if not last_msg:
            continue

        partner = db.query(db_models.User).filter(db_models.User.id == pid).first()
        if not partner:
            continue

        # Messages non lus reçus de ce partenaire (direct + broadcast individuel)
        unread = (
            db.query(db_models.Message)
            .filter(
                db_models.Message.sender_id == pid,
                db_models.Message.receiver_id == current_user.id,
                db_models.Message.is_read == False,
            )
            .count()
        )

        seen_direct_partners.add(pid)
        conversations.append({
            "type": "direct",
            "partner_id": pid,
            "partner_name": partner.full_name or partner.email,
            "partner_role": partner.role,
            "partner_avatar": getattr(partner, "avatar_url", None),
            "last_message": last_msg.content[:80],
            "last_message_at": _utc_iso(last_msg.created_at),
            "unread_count": unread,
            "last_is_mine": last_msg.sender_id == current_user.id,
        })

    # ── 2. Conversations de groupes de citoyens (éducateur) ──────────────────
    group_msgs = (
        db.query(db_models.Message)
        .filter(
            db_models.Message.sender_id == current_user.id,
            db_models.Message.group_id.isnot(None),
        )
        .order_by(db_models.Message.group_id, db_models.Message.created_at.desc())
        .all()
    )
    seen_groups: set[int] = set()
    for gm in group_msgs:
        if gm.group_id in seen_groups:
            continue
        seen_groups.add(gm.group_id)
        group = db.query(db_models.CitizenGroup).filter(
            db_models.CitizenGroup.id == gm.group_id).first()
        if not group:
            continue
        conversations.append({
            "type": "citizen_group",
            "group_id": gm.group_id,
            "group_name": group.name,
            "group_color": group.color,
            "member_count": len(group.members),
            "last_message": gm.content[:80],
            "last_message_at": _utc_iso(gm.created_at),
            "unread_count": 0,
            "last_is_mine": True,
        })

    # Ajouter les groupes dont je suis membre (messages reçus)
    my_group_msgs = (
        db.query(db_models.MessageGroupRecipient)
        .filter(db_models.MessageGroupRecipient.user_id == current_user.id)
        .join(db_models.Message, db_models.Message.id == db_models.MessageGroupRecipient.message_id)
        .filter(db_models.Message.group_id.isnot(None))
        .order_by(db_models.Message.group_id, db_models.Message.created_at.desc())
        .all()
    )
    for mgr in my_group_msgs:
        msg = mgr.message
        if not msg or msg.group_id in seen_groups:
            continue
        seen_groups.add(msg.group_id)
        group = db.query(db_models.CitizenGroup).filter(
            db_models.CitizenGroup.id == msg.group_id).first()
        if not group:
            continue
        unread_grp = (
            db.query(db_models.MessageGroupRecipient)
            .join(db_models.Message)
            .filter(
                db_models.Message.group_id == msg.group_id,
                db_models.MessageGroupRecipient.user_id == current_user.id,
                db_models.MessageGroupRecipient.is_read == False,
            )
            .count()
        )
        conversations.append({
            "type": "citizen_group",
            "group_id": msg.group_id,
            "group_name": group.name,
            "group_color": group.color,
            "member_count": len(group.members),
            "last_message": msg.content[:80],
            "last_message_at": _utc_iso(msg.created_at),
            "unread_count": unread_grp,
            "last_is_mine": False,
        })

    # ── 3. Broadcasts collecteurs (messages reçus via MessageGroupRecipient) ───
    # Uniquement pour les broadcasts sans receiver_id individuel (broadcasts multi-collecteurs)
    # Les broadcasts individuels (receiver_id défini) sont déjà gérés en section 1.
    broadcast_received = (
        db.query(db_models.MessageGroupRecipient)
        .filter(db_models.MessageGroupRecipient.user_id == current_user.id)
        .join(db_models.Message, db_models.Message.id == db_models.MessageGroupRecipient.message_id)
        .filter(db_models.Message.group_id.is_(None), db_models.Message.is_group_broadcast == True)
        .order_by(db_models.Message.sender_id, db_models.Message.created_at.desc())
        .all()
    )
    seen_broadcast_senders: set[int] = set()
    for mgr in broadcast_received:
        msg = mgr.message
        if not msg or msg.sender_id in seen_broadcast_senders:
            continue
        seen_broadcast_senders.add(msg.sender_id)

        # Ignorer si ce sender est déjà dans les conversations directes (évite doublons)
        if msg.sender_id in seen_direct_partners:
            continue

        sender = db.query(db_models.User).filter(db_models.User.id == msg.sender_id).first()
        unread_bc = (
            db.query(db_models.MessageGroupRecipient)
            .join(db_models.Message)
            .filter(
                db_models.Message.sender_id == msg.sender_id,
                db_models.Message.is_group_broadcast == True,
                db_models.Message.group_id.is_(None),
                db_models.MessageGroupRecipient.user_id == current_user.id,
                db_models.MessageGroupRecipient.is_read == False,
            )
            .count()
        )
        conversations.append({
            "type": "broadcast",
            "partner_id": msg.sender_id,
            "partner_name": sender.full_name if sender else "?",
            "partner_role": sender.role if sender else "?",
            "partner_avatar": sender.avatar_url if sender else None,
            "collector_group_label": msg.collector_group_label,
            "last_message": msg.content[:80],
            "last_message_at": _utc_iso(msg.created_at),
            "unread_count": unread_bc,
            "last_is_mine": False,
        })

    # Trier par date décroissante
    conversations.sort(
        key=lambda c: c.get("last_message_at") or "",
        reverse=True
    )
    return conversations


# ──────────────────────────────────────────────────────────────────────────────
# GET /messages/conversation/{user_id} — Messages 1-à-1
# ──────────────────────────────────────────────────────────────────────────────

@router.get("/conversation/{user_id}")
async def get_conversation(
    user_id: int,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Retourne TOUS les messages échangés entre current_user et user_id,
    qu'ils soient directs (is_group_broadcast=False) ou broadcasts individuels
    (is_group_broadcast=True mais avec receiver_id explicite).
    Cela garantit que la Mairie voit tous les messages envoyés au Collecteur
    même ceux émis via le endpoint broadcast.
    """
    msgs = (
        db.query(db_models.Message)
        .filter(
            or_(
                # Messages directs (1-à-1 classiques)
                and_(
                    db_models.Message.sender_id == current_user.id,
                    db_models.Message.receiver_id == user_id,
                    db_models.Message.is_group_broadcast == False,
                ),
                and_(
                    db_models.Message.sender_id == user_id,
                    db_models.Message.receiver_id == current_user.id,
                    db_models.Message.is_group_broadcast == False,
                ),
                # Broadcasts envoyés à cet utilisateur spécifique
                # (is_group_broadcast=True mais receiver_id défini = cas intercommunality→collector)
                and_(
                    db_models.Message.sender_id == current_user.id,
                    db_models.Message.receiver_id == user_id,
                    db_models.Message.is_group_broadcast == True,
                    db_models.Message.group_id.is_(None),
                ),
                and_(
                    db_models.Message.sender_id == user_id,
                    db_models.Message.receiver_id == current_user.id,
                    db_models.Message.is_group_broadcast == True,
                    db_models.Message.group_id.is_(None),
                ),
            )
        )
        .order_by(db_models.Message.created_at.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    # Marquer comme lus
    unread = [m for m in msgs
              if m.receiver_id == current_user.id and not m.is_read]
    for m in unread:
        m.is_read = True
    if unread:
        db.commit()

    partner = db.query(db_models.User).filter(db_models.User.id == user_id).first()
    return {
        "partner": {
            "id": partner.id,
            "full_name": partner.full_name,
            "role": partner.role,
            "avatar_url": partner.avatar_url,
        } if partner else None,
        "messages": [_serialize_message(m, current_user.id) for m in msgs],
    }


# ──────────────────────────────────────────────────────────────────────────────
# GET /messages/group-conversation/{group_id}
# ──────────────────────────────────────────────────────────────────────────────

@router.get("/group-conversation/{group_id}")
async def get_group_conversation(
    group_id: int,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    group = db.query(db_models.CitizenGroup).filter(db_models.CitizenGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")

    msgs = (
        db.query(db_models.Message)
        .filter(db_models.Message.group_id == group_id)
        .order_by(db_models.Message.created_at.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    # Marquer comme lus pour l'utilisateur courant
    my_unread = (
        db.query(db_models.MessageGroupRecipient)
        .join(db_models.Message, db_models.Message.id == db_models.MessageGroupRecipient.message_id)
        .filter(
            db_models.Message.group_id == group_id,
            db_models.MessageGroupRecipient.user_id == current_user.id,
            db_models.MessageGroupRecipient.is_read == False,
        )
        .all()
    )
    for mgr in my_unread:
        mgr.is_read = True
    if my_unread:
        db.commit()

    return {
        "group": {
            "id": group.id,
            "name": group.name,
            "color": group.color,
            "member_count": len(group.members),
        },
        "messages": [_serialize_message(m, current_user.id) for m in msgs],
    }


# ──────────────────────────────────────────────────────────────────────────────
# POST /messages/{message_id}/reply
# ──────────────────────────────────────────────────────────────────────────────

@router.post("/{message_id}/reply", status_code=status.HTTP_201_CREATED)
async def reply_to_message(
    message_id: int,
    payload: ReplyMessageIn,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    parent = db.query(db_models.Message).filter(db_models.Message.id == message_id).first()
    if not parent:
        raise HTTPException(status_code=404, detail="Message introuvable")

    # Déterminer le destinataire de la réponse
    if parent.sender_id == current_user.id:
        # Je réponds à mon propre message → répondre au destinataire
        receiver_id = parent.receiver_id
    else:
        # Je réponds à quelqu'un d'autre → répondre à l'expéditeur
        receiver_id = parent.sender_id

    if receiver_id:
        receiver = db.query(db_models.User).filter(db_models.User.id == receiver_id).first()
        if receiver:
            _check_can_message(current_user.role, receiver.role)

    reply = db_models.Message(
        sender_id=current_user.id,
        receiver_id=receiver_id,
        group_id=parent.group_id,
        is_group_broadcast=parent.is_group_broadcast,
        content=payload.content,
        parent_id=message_id,
    )
    db.add(reply)
    db.commit()
    db.refresh(reply)

    # ── Push FCM au destinataire de la réponse ────────────────────────────────
    if receiver_id:
        try:
            from services.fcm_push_service import send_push_to_user as _fcm
            sender_name = current_user.full_name or "Quelqu'un"
            _fcm(
                db,
                receiver_id,
                title=sender_name,
                body=payload.content[:120],
                data={
                    "type": "message",
                    "sender_id": str(current_user.id),
                    "sender_name": sender_name,
                    "partner_id": str(current_user.id),
                },
            )
        except Exception:
            pass  # Push non bloquant

    return _serialize_message(reply, current_user.id)


# ──────────────────────────────────────────────────────────────────────────────
# PUT /messages/{message_id}/read
# ──────────────────────────────────────────────────────────────────────────────

@router.put("/{message_id}/read")
async def mark_as_read(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    msg = db.query(db_models.Message).filter(db_models.Message.id == message_id).first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message introuvable")

    if msg.receiver_id == current_user.id:
        msg.is_read = True
        db.commit()

    # Marquer aussi dans les group recipients
    mgr = (
        db.query(db_models.MessageGroupRecipient)
        .filter(
            db_models.MessageGroupRecipient.message_id == message_id,
            db_models.MessageGroupRecipient.user_id == current_user.id,
        )
        .first()
    )
    if mgr:
        mgr.is_read = True
        db.commit()

    return {"ok": True}


# ──────────────────────────────────────────────────────────────────────────────
# POST /messages/conversation/{user_id}/read-all
# Marque TOUS les messages non lus d'une conversation comme lus en un seul appel.
# Utilisé par Flutter dès l'ouverture d'une conversation pour déclencher
# la mise à jour immédiate des coches bleues côté expéditeur.
# ──────────────────────────────────────────────────────────────────────────────

@router.post("/conversation/{user_id}/read-all")
async def mark_conversation_read_all(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Marque tous les messages reçus de user_id comme lus."""
    unread = (
        db.query(db_models.Message)
        .filter(
            db_models.Message.sender_id == user_id,
            db_models.Message.receiver_id == current_user.id,
            db_models.Message.is_read == False,
            db_models.Message.is_group_broadcast == False,
        )
        .all()
    )
    count = len(unread)
    for m in unread:
        m.is_read = True
    if unread:
        db.commit()
    return {"marked": count}
