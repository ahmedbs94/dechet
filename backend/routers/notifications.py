# routers/notifications.py — User notifications + FCM Push
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional

import db_models as db_models
from database import get_db
from core.deps import get_current_user, _utc_iso

router = APIRouter(prefix="/notifications", tags=["notifications"])


# ── Schémas ───────────────────────────────────────────────────────────────────

class FCMTokenRequest(BaseModel):
    token: str

class BroadcastRequest(BaseModel):
    title: str
    body: str
    image_url: Optional[str] = None
    data: Optional[dict] = None


# ── Notifications en base ──────────────────────────────────────────────────────

@router.get("")
async def get_notifications(skip: int = 0, limit: int = 50,
                             db: Session = Depends(get_db),
                             current_user: db_models.User = Depends(get_current_user)):
    notifs = (
        db.query(db_models.Notification)
        .filter(db_models.Notification.user_id == current_user.id)
        .order_by(db_models.Notification.created_at.desc())
        .offset(skip).limit(limit).all()
    )
    return [
        {
            "id": n.id, "type": n.type, "title": n.title, "body": n.body,
            "from_user_name": n.from_user_name, "post_id": n.post_id,
            "comment_id":             getattr(n, "comment_id",             None),
            "sender_id":              getattr(n, "sender_id",              None),
            "source_notification_id": getattr(n, "source_notification_id", None),
            "is_read": n.is_read, "created_at": _utc_iso(n.created_at),
        }
        for n in notifs
    ]


@router.get("/unread-count")
async def unread_count(db: Session = Depends(get_db),
                       current_user: db_models.User = Depends(get_current_user)):
    count = db.query(db_models.Notification).filter(
        db_models.Notification.user_id == current_user.id,
        db_models.Notification.is_read == False,
    ).count()
    return {"count": count}


@router.put("/read-all")
async def mark_all_read(db: Session = Depends(get_db),
                        current_user: db_models.User = Depends(get_current_user)):
    db.query(db_models.Notification).filter(
        db_models.Notification.user_id == current_user.id,
        db_models.Notification.is_read == False,
    ).update({"is_read": True})
    db.commit()
    return {"message": "Toutes les notifications marquées comme lues"}


@router.put("/{notif_id}/read")
async def mark_read(notif_id: int, db: Session = Depends(get_db),
                    current_user: db_models.User = Depends(get_current_user)):
    notif = db.query(db_models.Notification).filter(
        db_models.Notification.id == notif_id,
        db_models.Notification.user_id == current_user.id,
    ).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification non trouvée")
    notif.is_read = True
    db.commit()
    return {"message": "Notification lue"}


@router.put("/{notif_id}/unread")
async def mark_unread(notif_id: int, db: Session = Depends(get_db),
                      current_user: db_models.User = Depends(get_current_user)):
    notif = db.query(db_models.Notification).filter(
        db_models.Notification.id == notif_id,
        db_models.Notification.user_id == current_user.id,
    ).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification non trouvée")
    notif.is_read = False
    db.commit()
    return {"message": "Notification marquée comme non lue"}


class ActorReplyRequest(BaseModel):
    message: str


@router.post("/{notif_id}/reply")
async def actor_reply(
    notif_id: int,
    data: ActorReplyRequest,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Permet à un acteur (gestionnaire, collecteur, éducateur) de répondre
    à un message reu de l'intercommunalité.
    Crée une notification de type 'actor_reply' dans la boîte de l'expéditeur d'origine.
    """
    # Vérifier que l'acteur est bien le destinataire de la notification d'origine
    original = db.query(db_models.Notification).filter(
        db_models.Notification.id == notif_id,
        db_models.Notification.user_id == current_user.id,
        db_models.Notification.type.in_([
            "intercommunality_message",
            "intercommunality_group_message",
        ]),
    ).first()
    if not original:
        raise HTTPException(
            status_code=404,
            detail="Message introuvable ou vous n'êtes pas autorisé à répondre",
        )

    # Retrouver l'expéditeur (l'intercommunalité qui a envoyé le message)
    sender_id = getattr(original, "sender_id", None)
    if not sender_id:
        # Fallback : chercher par from_user_name
        sender = db.query(db_models.User).filter(
            db_models.User.full_name == original.from_user_name,
            db_models.User.role == "intercommunality",
        ).first()
        if sender:
            sender_id = sender.id

    if not sender_id:
        raise HTTPException(status_code=422, detail="Impossible d'identifier le destinataire de la réponse")

    # Créer la notification de réponse dans la boîte de l'intercommunalité
    reply_notif = db_models.Notification(
        user_id                = sender_id,
        sender_id              = current_user.id,
        type                   = "actor_reply",
        title                  = f"Réponse de {current_user.full_name}",
        body                   = data.message,
        from_user_name         = current_user.full_name,
        source_notification_id = notif_id,
        is_read                = False,
    )
    db.add(reply_notif)

    # Marquer le message original comme lu (l'acteur a répondu, donc l'a lu)
    original.is_read = True
    db.commit()
    db.refresh(reply_notif)

    # ── Push FCM : notifier l'intercommunalité de la réponse ─────────────────
    try:
        from services.fcm_push_service import send_push_to_user as _fcm_push
        _fcm_push(
            db, sender_id,
            title=f"Réponse de {current_user.full_name}",
            body=data.message,
            data={
                "type":     "actor_reply",
                "from":     str(current_user.id),
                "notif_id": str(reply_notif.id),
            },
        )
    except Exception:
        pass  # Non bloquant

    return {
        "message":       "Réponse envoyée avec succès",
        "reply_notif_id": reply_notif.id,
    }


# ── FCM Push Notifications ─────────────────────────────────────────────────────

@router.put("/fcm-token")
async def update_fcm_token(
    request: FCMTokenRequest,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Enregistre ou met à jour le token FCM de l'utilisateur connecté.
    Appelé automatiquement par l'app Flutter au démarrage.
    """
    from services.fcm_push_service import register_fcm_token
    success = register_fcm_token(db, current_user.id, request.token)
    if not success:
        raise HTTPException(status_code=500, detail="Impossible d'enregistrer le token FCM")
    return {"message": "Token FCM enregistré avec succès"}


@router.post("/broadcast")
async def broadcast_push_to_all(
    request: BroadcastRequest,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Envoie une push notification à TOUS les utilisateurs actifs.
    Réservé aux administrateurs.
    """
    if current_user.role not in ("admin", "intercommunality"):
        raise HTTPException(status_code=403, detail="Réservé aux administrateurs")

    from services.fcm_push_service import send_push_to_all
    result = send_push_to_all(
        db=db,
        title=request.title,
        body=request.body,
        data=request.data,
        image_url=request.image_url,
    )
    return {
        "message": f"Broadcast envoyé : {result['success']} succès, {result['failed']} échecs",
        "success": result["success"],
        "failed": result["failed"],
    }
