# routers/community.py — Testimonials, Center Proposals, Stats, QR, Tips
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

import db_models as db_models
import models as models
from database import get_db
from core.deps import get_current_user, get_admin_user, _utc_iso

router = APIRouter(tags=["community"])

# ── Testimonials ──────────────────────────────────────────────────────────────

def _format_testimonial(t) -> dict:
    return {
        "id": t.id,
        "user_id": t.user_id,
        "user_name": t.user_name,
        "user_avatar_url": t.user_avatar_url or "",
        "content": t.content,
        "rating": t.rating,
        "is_approved": t.is_approved,
        "is_featured": t.is_featured,
        "created_at": _utc_iso(t.created_at),
    }


@router.get("/testimonials")
async def list_testimonials(approved_only: bool = True, db: Session = Depends(get_db)):
    """Liste les témoignages. Par défaut : seulement les approuvés (public).
    approved_only=false retourne tous les témoignages (usage admin via /admin/testimonials recommandé)."""
    query = db.query(db_models.Testimonial)
    if approved_only:
        query = query.filter(db_models.Testimonial.is_approved == True)
    return [
        _format_testimonial(t)
        for t in query.order_by(db_models.Testimonial.created_at.desc()).all()
    ]


@router.get("/admin/testimonials")
async def admin_list_testimonials(
    status: Optional[str] = None,  # "pending" | "approved" | None (all)
    skip: int = 0, limit: int = 50,
    db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user),
):
    """Liste tous les témoignages pour l'admin, avec filtre optionnel."""
    query = db.query(db_models.Testimonial)
    if status == "pending":
        query = query.filter(db_models.Testimonial.is_approved == False)
    elif status == "approved":
        query = query.filter(db_models.Testimonial.is_approved == True)
    total = query.count()
    items = query.order_by(db_models.Testimonial.created_at.desc()).offset(skip).limit(limit).all()
    return {
        "total": total,
        "testimonials": [_format_testimonial(t) for t in items],
    }


@router.get("/testimonials/landing")
async def get_landing_testimonials(limit: int = 12, db: Session = Depends(get_db)):
    """Endpoint public pour la page marketing — retourne les témoignages approuvés,
    les témoignages mis en avant (featured) apparaissent en premier."""
    from sqlalchemy import case as sa_case
    testimonials = (
        db.query(db_models.Testimonial)
        .filter(db_models.Testimonial.is_approved == True)
        .order_by(
            db_models.Testimonial.is_featured.desc(),
            db_models.Testimonial.rating.desc(),
            db_models.Testimonial.created_at.desc(),
        )
        .limit(min(limit, 50))
        .all()
    )
    return [_format_testimonial(t) for t in testimonials]


@router.post("/testimonials")
async def create_testimonial(data: models.TestimonialCreate, db: Session = Depends(get_db),
                              current_user: db_models.User = Depends(get_current_user)):
    t = db_models.Testimonial(
        user_id=current_user.id,
        user_name=current_user.full_name or current_user.email,
        user_avatar_url=current_user.avatar_url,
        content=data.content,
        rating=max(1, min(5, data.rating)),
        is_approved=False,
    )
    db.add(t)
    db.commit()
    db.refresh(t)
    return {"message": "Témoignage soumis, en attente d'approbation", "id": t.id}


@router.put("/admin/testimonials/{testimonial_id}/approve")
async def approve_testimonial(testimonial_id: int, db: Session = Depends(get_db),
                               admin: db_models.User = Depends(get_admin_user)):
    t = db.query(db_models.Testimonial).filter(db_models.Testimonial.id == testimonial_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Témoignage non trouvé")
    t.is_approved = True
    db.commit()
    return {"message": "Témoignage approuvé"}


@router.put("/admin/testimonials/{testimonial_id}/reject")
async def reject_testimonial(testimonial_id: int, db: Session = Depends(get_db),
                              admin: db_models.User = Depends(get_admin_user)):
    t = db.query(db_models.Testimonial).filter(db_models.Testimonial.id == testimonial_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Témoignage non trouvé")
    db.delete(t)
    db.commit()
    return {"message": "Témoignage supprimé"}


@router.put("/admin/testimonials/{testimonial_id}/feature")
async def feature_testimonial(testimonial_id: int, db: Session = Depends(get_db),
                               admin: db_models.User = Depends(get_admin_user)):
    t = db.query(db_models.Testimonial).filter(db_models.Testimonial.id == testimonial_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Témoignage non trouvé")
    t.is_featured = not t.is_featured
    db.commit()
    return {"message": "Mis en avant" if t.is_featured else "Retiré des favoris", "is_featured": t.is_featured}


@router.delete("/testimonials/{testimonial_id}")
async def delete_testimonial(testimonial_id: int, db: Session = Depends(get_db),
                              current_user: db_models.User = Depends(get_current_user)):
    t = db.query(db_models.Testimonial).filter(db_models.Testimonial.id == testimonial_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Témoignage non trouvé")
    if t.user_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")
    db.delete(t)
    db.commit()
    return {"message": "Témoignage supprimé"}


# ── Center Proposals ──────────────────────────────────────────────────────────

@router.get("/center-proposals", response_model=List[models.CenterProposalResponse])
async def list_proposals(skip: int = 0, limit: int = 50, status: Optional[str] = None,
                         db: Session = Depends(get_db),
                         admin: db_models.User = Depends(get_admin_user)):
    """Liste les propositions de centres (admin uniquement)."""
    query = db.query(db_models.CenterProposal)
    if status:
        query = query.filter(db_models.CenterProposal.status == status)
    return query.order_by(db_models.CenterProposal.created_at.desc()).offset(skip).limit(limit).all()


@router.post("/center-proposals", response_model=models.CenterProposalResponse)
async def create_proposal(data: models.CenterProposalCreate, db: Session = Depends(get_db),
                           current_user: db_models.User = Depends(get_current_user)):
    if not data.name.strip() or not data.address.strip():
        raise HTTPException(status_code=400, detail="Nom et adresse obligatoires")
    proposal = db_models.CenterProposal(
        user_id=current_user.id, user_name=current_user.full_name or "Citoyen",
        name=data.name.strip(), address=data.address.strip(),
        lat=data.lat, lng=data.lng,
        waste_types=data.waste_types, description=(data.description or "").strip(),
        status="pending",
    )
    db.add(proposal)
    db.commit()
    db.refresh(proposal)
    return proposal


@router.delete("/center-proposals/{proposal_id}")
async def delete_proposal(proposal_id: int, db: Session = Depends(get_db),
                           current_user: db_models.User = Depends(get_current_user)):
    proposal = db.query(db_models.CenterProposal).filter(
        db_models.CenterProposal.id == proposal_id).first()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposition non trouvée")
    if proposal.user_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")
    db.delete(proposal)
    db.commit()
    return {"message": "Proposition supprimée"}


@router.put("/center-proposals/{proposal_id}/status")
async def update_proposal_status(proposal_id: int, status_update: dict,
                                  db: Session = Depends(get_db),
                                  admin: db_models.User = Depends(get_admin_user)):
    proposal = db.query(db_models.CenterProposal).filter(
        db_models.CenterProposal.id == proposal_id).first()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposition non trouvée")
    new_status = status_update.get("status", "").strip()
    if new_status not in ("pending", "approved", "rejected"):
        raise HTTPException(status_code=400, detail="Statut invalide")
    proposal.status = new_status
    db.commit()
    return {"message": f"Statut: {new_status}", "proposal_id": proposal_id}


# ── Stats ─────────────────────────────────────────────────────────────────────

@router.get("/stats")
async def get_stats(db: Session = Depends(get_db)):
    total_users = db.query(func.count(db_models.User.id)).filter(db_models.User.is_active == True).scalar() or 0
    total_posts = db.query(func.count(db_models.Post.id)).scalar() or 0
    total_likes = db.query(func.sum(db_models.Post.likes_count)).scalar() or 0
    total_comments = db.query(func.count(db_models.Comment.id)).scalar() or 0
    total_collection_points = db.query(func.count(db_models.CollectionPoint.id)).scalar() or 0
    pending_testimonials = db.query(func.count(db_models.Testimonial.id)).filter(db_models.Testimonial.is_approved == False).scalar() or 0
    total_testimonials = db.query(func.count(db_models.Testimonial.id)).scalar() or 0
    co2 = round(total_users * 1.5 + total_posts * 0.3 + (total_likes or 0) * 0.05, 1)
    return {
        "total_users": total_users, "total_posts": total_posts,
        "total_likes": int(total_likes or 0), "total_comments": total_comments,
        "total_collection_points": total_collection_points,
        "pending_testimonials": pending_testimonials,
        "total_testimonials": total_testimonials,
        "co2_saved_kg": co2, "trees_equivalent": max(1, int(co2 / 22)),
        "waste_sorted_kg": round(total_users * 2.1 + total_posts * 0.8, 1),
    }


# ── QR ────────────────────────────────────────────────────────────────────────

@router.post("/qr/verify")
async def verify_qr(data: models.QRVerifyRequest, db: Session = Depends(get_db)):
    qr = data.qr_code.strip()
    if not qr:
        raise HTTPException(status_code=400, detail="QR code requis")
    user = db.query(db_models.User).filter(db_models.User.qr_code == qr).first()
    if not user:
        raise HTTPException(status_code=404, detail="QR code invalide")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Compte désactivé")
    return {"success": True, "user_id": user.id, "full_name": user.full_name,
            "email": user.email, "role": user.role, "qr_code": user.qr_code}


@router.get("/qr/check-unique/{qr_code}")
async def check_qr_unique(qr_code: str, db: Session = Depends(get_db)):
    count = db.query(db_models.User).filter(db_models.User.qr_code == qr_code).count()
    return {"qr_code": qr_code, "is_unique": count <= 1, "count": count}


# ── Eco Tips ──────────────────────────────────────────────────────────────────

ECO_TIPS = [
    {"tip": "Rincez vos contenants en plastique avant de les jeter.", "icon": "water_drop"},
    {"tip": "Les bouchons en plastique se recyclent séparément — collectez-les !", "icon": "recycling"},
    {"tip": "Un smartphone peut être reconditionné plutôt que jeté.", "icon": "phone_android"},
    {"tip": "Le papier aluminium propre se recycle, sinon ordures ménagères.", "icon": "cleaning_services"},
    {"tip": "Apportez vos propres sacs au supermarché.", "icon": "shopping_bag"},
    {"tip": "Les piles usagées vont dans un point de collecte, jamais à la poubelle.", "icon": "battery_alert"},
    {"tip": "Un compost maison réduit vos déchets de cuisine de 30%.", "icon": "compost"},
    {"tip": "Privilégiez l'eau du robinet : moins de plastique.", "icon": "local_drink"},
    {"tip": "Les vêtements usagés peuvent être donnés, pas jetés.", "icon": "checkroom"},
    {"tip": "Éteignez les appareils en veille — 10% de votre électricité.", "icon": "power_off"},
    {"tip": "Les cartouches d'encre se recyclent en magasin spécialisé.", "icon": "print"},
    {"tip": "Achetez en vrac pour réduire les emballages.", "icon": "inventory_2"},
    {"tip": "Les médicaments périmés se rapportent en pharmacie.", "icon": "medication"},
    {"tip": "Réparez avant de remplacer.", "icon": "build"},
]


@router.get("/tips/daily")
async def daily_tip():
    day = datetime.utcnow().timetuple().tm_yday
    idx = day % len(ECO_TIPS)
    tip = ECO_TIPS[idx]
    return {"tip": tip["tip"], "icon": tip["icon"], "index": idx}
