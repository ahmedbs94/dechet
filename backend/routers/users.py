# routers/users.py — User management (admin CRUD + profile)
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List

import db_models as db_models
import models as models
from app.auth.service import get_password_hash
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
    query = db.query(db_models.User)
    if admin.role != "superadmin":
        query = query.filter(db_models.User.role.notin_(["admin", "superadmin"]))
    return query.offset(skip).limit(limit).all()


@router.post("/admin/users", response_model=models.User)
async def create_user(user: models.UserCreate, db: Session = Depends(get_db),
                      admin: db_models.User = Depends(get_admin_user)):
    if admin.role != "superadmin" and user.role in ["admin", "superadmin"]:
        raise HTTPException(
            status_code=403,
            detail="Seul le super-administrateur peut créer des administrateurs ou super-administrateurs"
        )
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
    if admin.role != "superadmin":
        if db_user.role in ["admin", "superadmin"]:
            raise HTTPException(
                status_code=403,
                detail="Seul le super-administrateur peut modifier un administrateur ou super-administrateur"
            )
        if user_update.role in ["admin", "superadmin"]:
            raise HTTPException(
                status_code=403,
                detail="Seul le super-administrateur peut attribuer le rôle d'administrateur ou super-administrateur"
            )
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
    if admin.role != "superadmin" and db_user.role in ["admin", "superadmin"]:
        raise HTTPException(
            status_code=403,
            detail="Seul le super-administrateur peut supprimer un administrateur ou super-administrateur"
        )
    db.delete(db_user)
    db.commit()
    return {"message": "Utilisateur supprimé"}


# ── Current user profile ──────────────────────────────────────────────────────

@router.get("/users/me")
async def get_me(
    current_user: db_models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Retourne le profil de l'utilisateur connecté.

    global_score : recalculé en temps réel depuis BinScan + QuizSubmission
    pour garantir la cohérence même si la colonne SQL est périmée.
    Si le vrai total diffère de la colonne, la colonne est corrigée.
    """
    # Recalcul depuis les tables sources (source de vérité)
    scan_pts = db.query(
        func.coalesce(func.sum(db_models.BinScan.points_earned), 0.0)
    ).filter(db_models.BinScan.user_id == current_user.id).scalar()

    quiz_pts = db.query(
        func.coalesce(func.sum(db_models.QuizSubmission.score), 0.0)
    ).filter(db_models.QuizSubmission.student_id == current_user.id).scalar()

    computed_score = round(float(scan_pts) + float(quiz_pts), 2)
    stored_score   = float(current_user.global_score or 0.0)

    # Si Firebase a poussé une valeur plus haute que SQL, on garde la plus haute
    true_score = max(computed_score, stored_score)

    # Corriger silencieusement la colonne si elle est désynchronisée
    if abs(stored_score - true_score) > 0.01:
        current_user.global_score = true_score
        db.add(current_user)
        db.commit()

    return {
        "id":           current_user.id,
        "email":        current_user.email,
        "full_name":    current_user.full_name,
        "role":         current_user.role,
        "avatar_url":   getattr(current_user, "avatar_url", None) or "",
        "qr_code":      current_user.qr_code,
        "points":       getattr(current_user, "points", 0),
        "global_score": true_score,
        "mfa_enabled":  getattr(current_user, "mfa_enabled", False) or False,
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

@router.post("/users/me/mfa/setup", response_model=models.MFASetupResponse)
async def setup_mfa(db: Session = Depends(get_db),
                    current_user: db_models.User = Depends(get_current_user)):
    """Initialise l'authentification forte en générant un secret TOTP."""
    import pyotp
    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)
    otpauth_url = totp.provisioning_uri(name=current_user.email, issuer_name="EcoRewind")
    
    current_user.mfa_secret = secret
    db.commit()
    db.refresh(current_user)
    
    return {"secret": secret, "otpauth_url": otpauth_url}


@router.post("/users/me/mfa/verify-enable")
async def verify_enable_mfa(data: models.MFAVerifyEnableRequest, db: Session = Depends(get_db),
                            current_user: db_models.User = Depends(get_current_user)):
    """Valide le code d'activation et active définitivement la MFA pour l'utilisateur."""
    import pyotp
    if not current_user.mfa_secret:
        raise HTTPException(status_code=400, detail="L'initialisation de la MFA n'a pas été demandée.")
        
    totp = pyotp.TOTP(current_user.mfa_secret)
    if not totp.verify(data.code, valid_window=1):
        raise HTTPException(status_code=400, detail="Code de validation incorrect ou expiré.")
        
    current_user.mfa_enabled = True
    db.commit()
    db.refresh(current_user)
    return {"message": "Authentification forte activée avec succès", "mfa_enabled": True}


@router.post("/users/me/mfa/disable")
async def disable_mfa(data: models.MFADisableRequest, db: Session = Depends(get_db),
                      current_user: db_models.User = Depends(get_current_user)):
    """Désactive l'authentification forte de manière sécurisée en exigeant une double confirmation."""
    import pyotp
    from app.auth.service import verify_password

    # Cas 1: L'utilisateur a un mot de passe (connexion classique)
    if current_user.hashed_password:
        if not data.password or not verify_password(data.password, current_user.hashed_password):
            raise HTTPException(status_code=400, detail="Mot de passe incorrect.")
    
    # Cas 2: L'utilisateur est connecté via un compte social et n'a pas de mot de passe
    else:
        if not data.code:
            raise HTTPException(status_code=400, detail="Code de validation MFA requis pour désactiver l'authentification forte.")
        totp = pyotp.TOTP(current_user.mfa_secret)
        if not totp.verify(data.code, valid_window=1):
            raise HTTPException(status_code=400, detail="Code de validation incorrect ou expiré.")

    current_user.mfa_enabled = False
    current_user.mfa_secret = None
    db.commit()
    db.refresh(current_user)
    return {"message": "Authentification forte désactivée", "mfa_enabled": False}


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
    """Historique chronologique des points gagnés par l'utilisateur (quiz, scans).

    Inclut aussi une entrée synthétique 'Capteur IoT' si global_score est
    supérieur à la somme des points tracés en SQL — cas des points enregistrés
    directement par l'Arduino dans Firebase sans créer de BinScan PostgreSQL.
    """
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

    # ── FIX : Points Arduino non tracés en SQL ────────────────────────────────
    # L'Arduino peut écrire directement dans Firebase /utilisateurs/{qr}/score
    # sans créer de BinScan en PostgreSQL. Ces points sont rattrapés dans
    # global_score par BinSync toutes les 5 min mais n'apparaissent pas dans
    # l'historique. On ajoute une entrée synthétique si l'écart est significatif.
    history_points_total = round(sum(h["points"] for h in history), 2)
    stored_score = round(float(current_user.global_score or 0), 2)
    arduino_delta = round(stored_score - history_points_total, 2)

    if arduino_delta > 0.01:
        history.append({
            "id": "arduino_iot",
            "type": "arduino",
            "points": arduino_delta,
            "date": None,  # pas de timestamp disponible pour les points Arduino directs
            "description": f"Points enregistrés par capteur IoT (+{arduino_delta} pts)"
        })

    # Trier par date décroissante (les entrées sans date vont en fin de liste)
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


# ═══════════════════════════════════════════════════════════════════════════════
# NIVEAUX & AVANTAGES & RÉCOMPENSES EXCLUSIVES
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/users/me/level", tags=["levels"])
async def get_my_level(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Retourne le palier actuel de l'utilisateur connecté, sa progression,
    ses avantages actifs, ses multiplicateurs de points et ses récompenses
    exclusives débloquées.

    Déclenche également le déblocage automatique des récompenses non encore
    enregistrées en base (idempotent grâce à la contrainte UNIQUE PostgreSQL).

    Réponse :
      - current_level    : palier actuel (rank, name, icon, color, min_points)
      - next_level       : prochain palier ou null si niveau maximum
      - score            : score global actuel
      - progress_percent : 0–100 % vers le palier suivant
      - points_to_next   : points manquants pour passer au palier suivant
      - scan_multiplier  : multiplicateur de points sur les scans QR
      - quiz_multiplier  : multiplicateur de points sur les quiz
      - advantages       : liste des avantages du palier actuel
      - unlocked_rewards : toutes les récompenses débloquées (historique)
      - newly_unlocked   : récompenses débloquées lors de cet appel
    """
    from app.levels.service import build_level_response

    # Recalcul du score depuis les sources (cohérent avec GET /users/me)
    scan_pts = db.query(
        func.coalesce(func.sum(db_models.BinScan.points_earned), 0.0)
    ).filter(db_models.BinScan.user_id == current_user.id).scalar()

    quiz_pts = db.query(
        func.coalesce(func.sum(db_models.QuizSubmission.score), 0.0)
    ).filter(db_models.QuizSubmission.student_id == current_user.id).scalar()

    computed_score = round(float(scan_pts) + float(quiz_pts), 2)
    stored_score   = float(current_user.global_score or 0.0)
    true_score     = max(computed_score, stored_score)

    # Corriger silencieusement si désynchronisé
    if abs(stored_score - true_score) > 0.01:
        current_user.global_score = true_score
        db.add(current_user)
        db.commit()

    return build_level_response(
        user_id=current_user.id,
        score=true_score,
        db=db,
    )


@router.get("/users/me/rewards", tags=["levels"])
async def get_my_rewards(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Retourne l'historique complet des récompenses exclusives débloquées
    par l'utilisateur connecté, triées par date de déblocage ascendante.

    Chaque récompense contient :
      - reward_key  : identifiant unique de la récompense
      - reward_type : "badge" | "discount" | "feature" | "certificate"
      - label       : nom affiché
      - description : description de la récompense
      - icon        : emoji représentant la récompense
      - unlocked_at : date ISO 8601 du déblocage
    """
    from app.levels.service import get_all_user_rewards

    rewards = get_all_user_rewards(current_user.id, db)
    return {
        "total": len(rewards),
        "rewards": [
            {
                "reward_key":  r.reward_key,
                "reward_type": r.reward_type,
                "label":       r.label,
                "description": r.description,
                "icon":        r.icon,
                "unlocked_at": r.unlocked_at.isoformat() if r.unlocked_at else None,
            }
            for r in rewards
        ],
    }


@router.get("/levels/all", tags=["levels"])
async def get_all_levels():
    """
    Retourne le référentiel public de tous les paliers EcoRewind
    avec leurs seuils de points, avantages et récompenses exclusives.

    Endpoint public (aucune authentification requise) — utilisé par le
    Flutter pour afficher l'écran 'Niveaux & Avantages'.
    """
    from app.levels.definitions import LEVELS

    return {
        "total_levels": len(LEVELS),
        "levels": [
            {
                "rank":        lvl.rank,
                "name":        lvl.name,
                "min_points":  lvl.min_points,
                "icon":        lvl.icon,
                "color":       lvl.color,
                "gradient":    lvl.gradient,
                "advantages": [
                    {
                        "key":         adv.key,
                        "label":       adv.label,
                        "description": adv.description,
                    }
                    for adv in lvl.advantages
                ],
                "exclusive_rewards": [
                    {
                        "key":         r.key,
                        "label":       r.label,
                        "description": r.description,
                        "icon":        r.icon,
                        "reward_type": r.reward_type,
                    }
                    for r in lvl.rewards
                ],
            }
            for lvl in LEVELS
        ],
    }
