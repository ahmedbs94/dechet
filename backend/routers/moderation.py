"""
EcoRewind Admin Moderation System
=================================
"""

from datetime import datetime, timedelta
from typing import Optional, List
import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc, func, and_

import db_models as db_models
from database import get_db
from core.deps import get_admin_user, _utc_iso
from services.firebase_service import update_admin_stats

router = APIRouter(prefix="/admin/moderation", tags=["moderation"])

def _format_post(p) -> dict:
    details = {}
    if p.moderation_details:
        try: details = json.loads(p.moderation_details)
        except: pass
    return {
        "id": p.id, "user_id": p.user_id, "user_name": p.user_name,
        "user_avatar_url": p.user_avatar_url or "", "image_url": p.image_url or "",
        "description": p.description or "", "created_at": _utc_iso(p.created_at),
        "likes_count": p.likes_count or 0, "status": p.status,
        "moderation_score": round(p.moderation_score or 0.0, 3),
        "moderation_reason": p.moderation_reason or "",
        "moderation_details": details,
    }

@router.get("/queue")
async def get_moderation_queue(skip: int = 0, limit: int = 50,
    priority: Optional[str] = None, db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user)):
    query = db.query(db_models.Post).filter(db_models.Post.status == "pending_review")
    if priority == "high": query = query.filter(db_models.Post.moderation_score >= 0.50)
    elif priority == "medium": query = query.filter(and_(db_models.Post.moderation_score >= 0.35, db_models.Post.moderation_score < 0.50))
    posts = query.order_by(desc(db_models.Post.created_at)).offset(skip).limit(limit).all()
    return {"posts": [_format_post(p) for p in posts], "total": query.count()}

@router.get("/pending")
async def get_pending_posts(skip: int = 0, limit: int = 50,
    db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    posts = db.query(db_models.Post).filter(db_models.Post.status == "pending_review").order_by(desc(db_models.Post.created_at)).offset(skip).limit(limit).all()
    return {"total": db.query(db_models.Post).filter(db_models.Post.status == "pending_review").count(), "posts": [_format_post(p) for p in posts]}

@router.get("/all")
async def get_all_posts_moderation(status: Optional[str] = None, skip: int = 0, limit: int = 50,
    db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    query = db.query(db_models.Post)
    if status: query = query.filter(db_models.Post.status == status)
    return {"total": query.count(), "posts": [_format_post(p) for p in query.order_by(desc(db_models.Post.created_at)).offset(skip).limit(limit).all()]}

@router.put("/{post_id}/approve")
async def approve_post(post_id: int, reason: Optional[str] = None,
    db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not post: raise HTTPException(status_code=404, detail="Publication non trouvée")
    if post.status == "published": return {"message": "Déjà approuvée"}
    post.status = "published"
    post.moderation_reason = reason or "Approuvé par l'administrateur"
    db.add(db_models.Notification(user_id=post.user_id, type="moderation", title="✅ Publication approuvée",
        body="Votre publication a été validée.", from_user_name="Administration EcoRewind", post_id=post_id))
    db.commit()
    # ── Sync Firebase : pending_moderation -1 ──────────────────────────────
    try:
        update_admin_stats(db)
    except Exception:
        pass
    return {"message": "Publication approuvée", "post_id": post_id}

@router.put("/{post_id}/reject")
async def reject_post(post_id: int, reason: Optional[str] = None,
    db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not post: raise HTTPException(status_code=404, detail="Publication non trouvée")
    reject_reason = reason or "Contenu ne respectant pas les règles"
    # Marquer comme rejected (pas supprimer) → comptabilisé dans les stats
    post.status = "rejected"
    post.moderation_reason = reject_reason
    db.add(db_models.Notification(user_id=post.user_id, type="moderation", title="❌ Publication refusée",
        body=f"Votre publication a été refusée par l'administrateur : {reject_reason}",
        from_user_name="Administration EcoRewind", post_id=post_id))
    db.commit()
    # ── Sync Firebase : pending_moderation -1 ──────────────────────────────
    try:
        update_admin_stats(db)
    except Exception:
        pass
    return {"message": "Publication rejetée", "post_id": post_id, "reason": reject_reason}

@router.post("/bulk/approve")
async def bulk_approve_posts(post_ids: List[int], reason: Optional[str] = None,
    db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    if len(post_ids) > 50: raise HTTPException(status_code=400, detail="Maximum 50 posts")
    count = 0
    for post_id in post_ids:
        post = db.query(db_models.Post).filter(db_models.Post.id == post_id, db_models.Post.status == "pending_review").first()
        if post:
            post.status = "published"
            post.moderation_reason = f"Bulk approved: {reason or 'Admin'}"
            db.add(db_models.Notification(user_id=post.user_id, type="moderation", title="✅ Publication approuvée",
                body="Votre publication a été validée.", from_user_name="Administration EcoRewind", post_id=post_id))
            count += 1
    db.commit()
    # ── Sync Firebase : pending_moderation recalculé (bulk) ────────────────
    try:
        update_admin_stats(db)
    except Exception:
        pass
    return {"message": f"{count} publications approuvées", "approved_count": count}

@router.post("/bulk/reject")
async def bulk_reject_posts(post_ids: List[int], reason: Optional[str] = None,
    db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    if len(post_ids) > 50: raise HTTPException(status_code=400, detail="Maximum 50 posts")
    reject_reason = reason or "Contenu ne respectant pas les règles"
    count = 0
    for post_id in post_ids:
        post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
        if post:
            post.status = "rejected"
            post.moderation_reason = f"Bulk rejected: {reject_reason}"
            db.add(db_models.Notification(user_id=post.user_id, type="moderation", title="❌ Publication refusée",
                body=f"Votre publication a été refusée : {reject_reason}",
                from_user_name="Administration EcoRewind", post_id=post_id))
            count += 1
    db.commit()
    # ── Sync Firebase : pending_moderation recalculé (bulk) ────────────────
    try:
        update_admin_stats(db)
    except Exception:
        pass
    return {"message": f"{count} publications rejetées", "rejected_count": count}

@router.get("/stats")
async def moderation_stats(db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    total       = db.query(db_models.Post).count()
    published   = db.query(db_models.Post).filter(db_models.Post.status == "published").count()
    pending_rev = db.query(db_models.Post).filter(db_models.Post.status == "pending_review").count()
    rejected    = db.query(db_models.Post).filter(db_models.Post.status == "rejected").count()
    avg_score   = db.query(func.avg(db_models.Post.moderation_score)).scalar() or 0

    # Posts bloqués : pending_review sans modération appliquée depuis > 10 min
    # Indique un échec de la BackgroundTask (pipeline principal)
    stale_threshold = datetime.utcnow() - timedelta(minutes=10)
    stale_count = (
        db.query(db_models.Post)
        .filter(
            db_models.Post.status == "pending_review",
            db_models.Post.moderated_at.is_(None),
            db_models.Post.created_at <= stale_threshold,
        )
        .count()
    )

    return {
        "total_posts":              total,
        "published":                published,
        "pending_review":           pending_rev,     # En attente de validation admin (signalés par l'IA)
        "stale_unmoderated":        stale_count,     # Posts bloqués (BackgroundTask échouée)
        "rejected":                 rejected,
        "auto_approve_rate":        round(published / total * 100, 1) if total > 0 else 0,
        "average_moderation_score": round(avg_score, 3),
        # Santé du pipeline : si des posts sont bloqués depuis > 10 min, l'IA a un problème
        "pipeline_health":          "ok" if stale_count == 0 else ("warning" if stale_count < 10 else "critical"),
    }


@router.get("/worker/status")
async def worker_status(db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    """
    Santé du pipeline de modération IA (BackgroundTasks).

    Détecte les posts bloqués en 'pending_review' sans modération appliquée
    depuis plus de 10 minutes — signe que la BackgroundTask a échouée.
    Le worker de rattrapage (ai_worker/worker.py) traite ces cas automatiquement.
    """
    stale_threshold = datetime.utcnow() - timedelta(minutes=10)

    # Posts non modérés bloqués depuis > 10 min
    stale_count = (
        db.query(db_models.Post)
        .filter(
            db_models.Post.status == "pending_review",
            db_models.Post.moderated_at.is_(None),
            db_models.Post.created_at <= stale_threshold,
        )
        .count()
    )

    # Post le plus ancien bloqué → indique le retard maximal
    oldest = (
        db.query(db_models.Post)
        .filter(
            db_models.Post.status == "pending_review",
            db_models.Post.moderated_at.is_(None),
            db_models.Post.created_at <= stale_threshold,
        )
        .order_by(db_models.Post.created_at.asc())
        .first()
    )

    # Dernier post modéré → indique que l'IA fonctionne bien
    last_moderated = (
        db.query(db_models.Post)
        .filter(db_models.Post.moderated_at.isnot(None))
        .order_by(db_models.Post.moderated_at.desc())
        .first()
    )

    oldest_stale_at   = _utc_iso(oldest.created_at) if oldest else None
    last_moderated_at = _utc_iso(last_moderated.moderated_at) if last_moderated else None

    # Retard maximal en minutes
    delay_minutes = None
    if oldest and oldest.created_at:
        dt = oldest.created_at.replace(tzinfo=None) if oldest.created_at.tzinfo else oldest.created_at
        delay_minutes = int((datetime.utcnow() - dt).total_seconds() / 60)

    pipeline_status = "ok"
    if stale_count >= 50:
        pipeline_status = "critical"   # BackgroundTasks probablement en erreur
    elif stale_count >= 10:
        pipeline_status = "warning"    # Retard inhabituel

    return {
        "pipeline_status":       pipeline_status,
        "stale_posts_count":     stale_count,      # Posts bloqués sans modération
        "oldest_stale_at":       oldest_stale_at,
        "last_moderated_at":     last_moderated_at,
        "delay_minutes":         delay_minutes,
        "pipeline_doc":          "Pipeline principal : BackgroundTasks dans routers/posts.py",
        "rescue_worker_doc":     "Rattrapage optionnel : python -m ai_worker.worker (depuis backend/)",
    }