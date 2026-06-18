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
            "comment_id": getattr(n, "comment_id", None),
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
