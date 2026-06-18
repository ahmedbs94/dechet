# routers/users.py — User management (admin CRUD + profile)
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List

import db_models as db_models
import models as models
from auth import get_password_hash
from database import get_db
from core.deps import get_current_user, get_admin_user

router = APIRouter(tags=["users"])


class AvatarUpdate(BaseModel):
    avatar_url: str


class ProfileUpdate(BaseModel):
    full_name: str


# ── Admin user management ─────────────────────────────────────────────────────

@router.get("/users", response_model=List[models.User])
async def list_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db),
                     admin: db_models.User = Depends(get_admin_user)):
    return db.query(db_models.User).offset(skip).limit(limit).all()


@router.post("/admin/users", response_model=models.User)
async def create_user(user: models.UserCreate, db: Session = Depends(get_db),
                      admin: db_models.User = Depends(get_admin_user)):
    if db.query(db_models.User).filter(db_models.User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")
    new_user = db_models.User(
        email=user.email, full_name=user.full_name,
        hashed_password=get_password_hash(user.password),
        role=user.role, is_active=True,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


@router.put("/admin/users/{user_id}", response_model=models.User)
async def update_user(user_id: int, user_update: models.UserUpdate,
                      db: Session = Depends(get_db),
                      admin: db_models.User = Depends(get_admin_user)):
    db_user = db.query(db_models.User).filter(db_models.User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    if user_update.full_name:
        db_user.full_name = user_update.full_name
    if user_update.role:
        db_user.role = user_update.role
    if user_update.password:
        db_user.hashed_password = get_password_hash(user_update.password)
    db.commit()
    db.refresh(db_user)
    return db_user


@router.delete("/admin/users/{user_id}")
async def delete_user(user_id: int, db: Session = Depends(get_db),
                      admin: db_models.User = Depends(get_admin_user)):
    db_user = db.query(db_models.User).filter(db_models.User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    db.delete(db_user)
    db.commit()
    return {"message": "Utilisateur supprimé"}


# ── Current user profile ──────────────────────────────────────────────────────

@router.get("/users/me")
async def get_me(current_user: db_models.User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "full_name": current_user.full_name,
        "role": current_user.role,
        "avatar_url": getattr(current_user, "avatar_url", None) or "",
        "qr_code": current_user.qr_code,
        "points": getattr(current_user, "points", 0),
        "global_score": getattr(current_user, "global_score", 0.0) or 0.0,
        "mfa_enabled": getattr(current_user, "mfa_enabled", False) or False,
    }


@router.put("/users/me")
async def update_me(data: ProfileUpdate, db: Session = Depends(get_db),
                    current_user: db_models.User = Depends(get_current_user)):
    """Met à jour le profil de l'utilisateur connecté (nom complet)."""
    full_name = data.full_name.strip()
    if not full_name:
        raise HTTPException(status_code=422, detail="Le nom ne peut pas être vide")
    current_user.full_name = full_name
    db.commit()
    db.refresh(current_user)
    return {"message": "Profil mis à jour", "full_name": current_user.full_name}


@router.put("/users/me/avatar")
async def update_avatar(data: AvatarUpdate, db: Session = Depends(get_db),
                        current_user: db_models.User = Depends(get_current_user)):
    current_user.avatar_url = data.avatar_url
    db.commit()
    db.refresh(current_user)
    return {"message": "Avatar mis à jour", "avatar_url": current_user.avatar_url}


# ── MFA (Authentification Forte) ──────────────────────────────────────────────

@router.post("/users/me/mfa/enable")
async def enable_mfa(db: Session = Depends(get_db),
                     current_user: db_models.User = Depends(get_current_user)):
    """Active l'authentification forte (MFA) pour l'utilisateur connecte."""
    current_user.mfa_enabled = True
    db.commit()
    db.refresh(current_user)
    return {"message": "Authentification forte activee", "mfa_enabled": True}


@router.post("/users/me/mfa/disable")
async def disable_mfa(db: Session = Depends(get_db),
                      current_user: db_models.User = Depends(get_current_user)):
    """Desactive l'authentification forte (MFA) pour l'utilisateur connecte."""
    current_user.mfa_enabled = False
    db.commit()
    db.refresh(current_user)
    return {"message": "Authentification forte desactivee", "mfa_enabled": False}


@router.get("/users/me/stats")
async def get_my_stats(db: Session = Depends(get_db),
                       current_user: db_models.User = Depends(get_current_user)):
    """Statistiques personnelles de l'utilisateur connecte."""
    from sqlalchemy import func

    posts_count = db.query(func.count(db_models.Post.id)).filter(
        db_models.Post.user_id == current_user.id,
        db_models.Post.status == "published",
    ).scalar() or 0

    likes_received = db.query(func.sum(db_models.Post.likes_count)).filter(
        db_models.Post.user_id == current_user.id,
        db_models.Post.status == "published",
    ).scalar() or 0

    comments_count = db.query(func.count(db_models.Comment.id)).filter(
        db_models.Comment.user_id == current_user.id,
    ).scalar() or 0

    saved_count = db.query(func.count(db_models.SavedPost.id)).filter(
        db_models.SavedPost.user_id == current_user.id,
    ).scalar() or 0

    return {
        "posts_count": posts_count,
        "likes_received": int(likes_received),
        "comments_count": comments_count,
        "saved_count": saved_count,
        "eco_score": posts_count * 10 + int(likes_received) * 2 + comments_count * 5,
    }


@router.get("/users/me/points-history")
async def get_points_history(db: Session = Depends(get_db),
                             current_user: db_models.User = Depends(get_current_user)):
    """Historique chronologique des points gagnés par l'utilisateur (quiz, scans)."""
    # 1. Récupérer les scans de poubelles
    scans = db.query(db_models.BinScan).filter(
        db_models.BinScan.user_id == current_user.id
    ).all()
    
    # 2. Récupérer les participations aux quiz
    quiz_submissions = db.query(db_models.QuizSubmission).join(
        db_models.Quiz, db_models.QuizSubmission.quiz_id == db_models.Quiz.id
    ).filter(
        db_models.QuizSubmission.student_id == current_user.id
    ).all()

    history = []

    for s in scans:
        if s.points_earned and s.points_earned > 0:
            history.append({
                "id": f"scan_{s.id}",
                "type": "tri",
                "points": s.points_earned,
                "date": s.scanned_at.isoformat() if s.scanned_at else None,
                "description": f"Tri de déchets - {s.waste_type or 'général'}"
            })

    for qs in quiz_submissions:
        if qs.score and qs.score > 0:
            history.append({
                "id": f"quiz_{qs.id}",
                "type": "quiz",
                "points": qs.score,
                "date": qs.submitted_at.isoformat() if qs.submitted_at else (qs.graded_at.isoformat() if qs.graded_at else None),
                "description": f"Quiz complété : {qs.quiz.title if qs.quiz else 'Quiz'}"
            })

    # Trier par date décroissante
    history.sort(key=lambda x: x["date"] or "", reverse=True)

    return history


@router.get("/users/me/impact")
async def get_my_impact(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Impact écologique personnel de l'utilisateur connecté.
    Calculé depuis ses vrais scans QR (poids réel si disponible, sinon estimé).

    Retourne :
    - scan_count          : nombre total de scans effectués
    - quiz_count          : nombre de quiz complétés
    - waste_sorted_kg     : kg de déchets triés (réels ou estimés)
    - co2_saved_kg        : CO₂ économisé (0.5 kg par kg de déchet trié)
    - trees_equivalent    : arbres équivalents (1 arbre ≈ 22 kg CO₂/an)
    - waste_by_type       : répartition par type de déchet
    - total_scan_points   : points gagnés via scans
    - total_quiz_points   : points gagnés via quiz
    - posts_count         : publications approuvées
    - likes_received      : total de likes reçus
    """
    from sqlalchemy import func

    # ── Scans ─────────────────────────────────────────────────────────────────
    scans = db.query(db_models.BinScan).filter(
        db_models.BinScan.user_id == current_user.id
    ).all()

    scan_count = len(scans)
    total_scan_points = sum(s.points_earned or 0.0 for s in scans)

    # Poids total : poids réel si renseigné, sinon estimation 0.5 kg/scan
    waste_sorted_kg = sum(
        s.weight_kg if (s.weight_kg and s.weight_kg > 0) else 0.5
        for s in scans
    )

    # Répartition par type de déchet
    waste_by_type: dict = {}
    for s in scans:
        wtype = (s.waste_type or "général").lower()
        wtype_kg = s.weight_kg if (s.weight_kg and s.weight_kg > 0) else 0.5
        waste_by_type[wtype] = round(waste_by_type.get(wtype, 0.0) + wtype_kg, 2)

    # Impact CO₂ : 0.5 kg CO₂ économisé par kg de déchets triés
    co2_saved_kg = round(waste_sorted_kg * 0.5, 2)
    trees_equivalent = max(0, int(co2_saved_kg / 22))

    # ── Quiz ──────────────────────────────────────────────────────────────────
    quiz_subs = db.query(db_models.QuizSubmission).filter(
        db_models.QuizSubmission.student_id == current_user.id
    ).all()
    quiz_count = len(quiz_subs)
    total_quiz_points = sum(qs.score or 0.0 for qs in quiz_subs)

    # ── Posts ─────────────────────────────────────────────────────────────────
    posts_count = db.query(func.count(db_models.Post.id)).filter(
        db_models.Post.user_id == current_user.id,
        db_models.Post.status == "published",
    ).scalar() or 0

    likes_received = db.query(func.sum(db_models.Post.likes_count)).filter(
        db_models.Post.user_id == current_user.id,
        db_models.Post.status == "published",
    ).scalar() or 0

    return {
        "scan_count":        scan_count,
        "quiz_count":        quiz_count,
        "waste_sorted_kg":   round(waste_sorted_kg, 2),
        "co2_saved_kg":      co2_saved_kg,
        "trees_equivalent":  trees_equivalent,
        "waste_by_type":     waste_by_type,
        "total_scan_points": round(total_scan_points, 1),
        "total_quiz_points": round(total_quiz_points, 1),
        "posts_count":       posts_count,
        "likes_received":    int(likes_received),
    }

