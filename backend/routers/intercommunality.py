"""
routers/intercommunality.py — Espace intercommunalité
======================================================
Strictement centré sur les 3 fonctions métier :

  1/ CONSIGNES LOCALES DE TRI
     Fournir des consignes locales sur le tri des déchets,
     afin d'assurer une cohérence avec les règles territoriales.

  2/ CENTRALISATION DES POINTS DE COLLECTE
     Centraliser l'information sur les points de collecte,
     afin de garantir une base de données fiable et à jour.

  3/ COORDINATION DES ACTEURS LOCAUX
     Coordonner les acteurs locaux (gestionnaires, prestataires, éducateurs),
     afin d'optimiser la politique de tri sur le territoire.

Accès : role == "intercommunality" ou "admin"
"""

from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

import db_models as db_models
from database import get_db
from core.deps import get_current_user
from app.intercommunality.models import LocalInstruction, CustomActorGroup
from app.intercommunality.schemas import (
    LocalInstructionCreate,
    LocalInstructionUpdate,
    LocalInstructionOut,
    CustomActorGroupCreate,
    CustomActorGroupOut,
    ActorNotifyRequest,
    GroupNotifyRequest,
)
from app.intercommunality.zone_models import CollectorZone, CollectorZoneAssignment
from app.intercommunality.zone_schemas import (
    CollectorZoneCreate,
    CollectorZoneUpdate,
    CollectorZoneOut,
    CollectorZoneAssignmentCreate,
    CollectorZoneAssignmentUpdate,
    CollectorZoneAssignmentOut,
)

router = APIRouter(prefix="/intercommunality", tags=["intercommunality"])


# ── Dépendance de rôle ────────────────────────────────────────────────────────

def _require_intercommunality(
    current_user: db_models.User = Depends(get_current_user),
):
    if current_user.role not in ("intercommunality", "admin"):
        raise HTTPException(
            status_code=403,
            detail="Accès réservé à l'intercommunalité",
        )
    return current_user


# ══════════════════════════════════════════════════════════════════════════════
# FONCTION 1 : CONSIGNES LOCALES DE TRI
# Fournir des consignes locales sur le tri des déchets
# afin d'assurer une cohérence avec les règles territoriales.
# ══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/instructions",
    response_model=List[LocalInstructionOut],
    summary="[F1] Liste des consignes locales de tri",
)
async def list_instructions(
    territory:  Optional[str]  = Query(None, description="Filtrer par territoire"),
    city:       Optional[str]  = Query(None, description="Filtrer par ville"),
    waste_type: Optional[str]  = Query(None, description="Filtrer par type de déchet"),
    is_active:  Optional[bool] = Query(None, description="Filtrer actives/inactives"),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Retourne toutes les consignes locales de tri.
    Chaque consigne précise les règles territoriales pour un type de déchet donné.
    Accessible à tous les utilisateurs connectés (citoyens inclus).
    """
    q = db.query(LocalInstruction)
    if territory:
        q = q.filter(LocalInstruction.territory.ilike(f"%{territory}%"))
    if city:
        q = q.filter(LocalInstruction.city.ilike(f"%{city}%"))
    if waste_type:
        q = q.filter(LocalInstruction.waste_type.ilike(f"%{waste_type}%"))
    if is_active is not None:
        q = q.filter(LocalInstruction.is_active == is_active)
    return q.order_by(LocalInstruction.territory, LocalInstruction.waste_type).all()


@router.post(
    "/instructions",
    response_model=LocalInstructionOut,
    summary="[F1] Créer une consigne locale de tri",
    status_code=201,
)
async def create_instruction(
    data: LocalInstructionCreate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Crée une nouvelle consigne locale de tri pour le territoire.
    Permet à l'intercommunalité d'édicter ses propres règles de tri
    conformes aux règlements locaux.
    """
    instruction = LocalInstruction(
        **data.dict(),
        created_by=current_user.id,
    )
    db.add(instruction)
    db.commit()
    db.refresh(instruction)
    return instruction


@router.get(
    "/instructions/{instruction_id}",
    response_model=LocalInstructionOut,
    summary="[F1] Détail d'une consigne",
)
async def get_instruction(
    instruction_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Retourne le détail complet d'une consigne locale."""
    instr = db.query(LocalInstruction).filter(LocalInstruction.id == instruction_id).first()
    if not instr:
        raise HTTPException(status_code=404, detail="Consigne introuvable")
    return instr


@router.put(
    "/instructions/{instruction_id}",
    response_model=LocalInstructionOut,
    summary="[F1] Modifier une consigne locale",
)
async def update_instruction(
    instruction_id: int,
    data: LocalInstructionUpdate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Met à jour une consigne locale existante.
    Utile lorsque les règles territoriales évoluent.
    """
    instr = db.query(LocalInstruction).filter(LocalInstruction.id == instruction_id).first()
    if not instr:
        raise HTTPException(status_code=404, detail="Consigne introuvable")
    for field, value in data.dict(exclude_unset=True).items():
        setattr(instr, field, value)
    instr.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(instr)
    return instr


@router.delete(
    "/instructions/{instruction_id}",
    summary="[F1] Supprimer une consigne locale",
)
async def delete_instruction(
    instruction_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """Supprime définitivement une consigne locale de tri."""
    instr = db.query(LocalInstruction).filter(LocalInstruction.id == instruction_id).first()
    if not instr:
        raise HTTPException(status_code=404, detail="Consigne introuvable")
    db.delete(instr)
    db.commit()
    return {"message": "Consigne supprimée avec succès"}


@router.get(
    "/instructions/summary",
    summary="[F1] Résumé des consignes par type de déchet",
)
async def instructions_summary(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Vue consolidée des consignes par type de déchet.
    Permet de vérifier la couverture des règles territoriales.
    """
    rows = (
        db.query(
            LocalInstruction.waste_type,
            func.count(LocalInstruction.id).label("total"),
            func.sum(
                func.cast(LocalInstruction.is_active, db.bind.dialect.name == "postgresql" and "integer" or "integer")
            ).label("active"),
        )
        .group_by(LocalInstruction.waste_type)
        .all()
    )

    total_active = (
        db.query(func.count(LocalInstruction.id))
        .filter(LocalInstruction.is_active == True)
        .scalar() or 0
    )
    total_inactive = (
        db.query(func.count(LocalInstruction.id))
        .filter(LocalInstruction.is_active == False)
        .scalar() or 0
    )

    by_waste_type = [
        {"waste_type": wt, "total": tot, "active": act or 0}
        for wt, tot, act in rows
    ]

    return {
        "total_active":   total_active,
        "total_inactive": total_inactive,
        "by_waste_type":  by_waste_type,
    }


# ══════════════════════════════════════════════════════════════════════════════
# FONCTION 2 : CENTRALISATION DES POINTS DE COLLECTE
# Centraliser l'information sur les points de collecte,
# afin de garantir une base de données fiable et à jour.
# ══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/collection-points",
    summary="[F2] Vue centralisée des points de collecte",
)
async def get_collection_points(
    status:   Optional[str] = Query(None, description="disponible / saturé / maintenance"),
    verified: Optional[bool] = Query(None, description="Filtrer par vérification"),
    search:   Optional[str]  = Query(None, description="Recherche par nom ou adresse"),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Vue centralisée de tous les points de collecte du territoire.
    Permet à l'intercommunalité de maintenir une base de données
    fiable, complète et à jour.
    """
    q = db.query(db_models.CollectionPoint)
    if status:
        q = q.filter(db_models.CollectionPoint.status == status)
    if verified is not None:
        q = q.filter(db_models.CollectionPoint.is_verified == verified)
    if search:
        s = f"%{search.lower()}%"
        q = q.filter(
            db_models.CollectionPoint.name.ilike(s)
            | db_models.CollectionPoint.address.ilike(s)
        )

    points = q.order_by(db_models.CollectionPoint.name).all()
    return [
        {
            "id":          p.id,
            "name":        p.name,
            "address":     p.address or "",
            "lat":         float(p.lat),
            "lng":         float(p.lng),
            "status":      p.status or "disponible",
            "load_level":  float(p.load_level or 0.0),
            "is_verified": p.is_verified,
            "hours":       p.hours or "",
            "types":       [t.strip() for t in (p.types or "").split(",") if t.strip()],
            "created_at":  p.created_at.isoformat() if p.created_at else None,
        }
        for p in points
    ]


@router.get(
    "/collection-points/overview",
    summary="[F2] Vue d'ensemble de la base de données des points de collecte",
)
async def collection_points_overview(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Synthèse de la qualité et complétude de la base de données
    des points de collecte : fiabilité, vérification, couverture.
    """
    total = db.query(func.count(db_models.CollectionPoint.id)).scalar() or 0
    verified = (
        db.query(func.count(db_models.CollectionPoint.id))
        .filter(db_models.CollectionPoint.is_verified == True)
        .scalar() or 0
    )
    unverified = total - verified

    by_status = {}
    for s in ("disponible", "saturé", "sature", "maintenance"):
        cnt = (
            db.query(func.count(db_models.CollectionPoint.id))
            .filter(db_models.CollectionPoint.status == s)
            .scalar() or 0
        )
        by_status[s] = cnt
    # Fusionner saturé / sature
    by_status["saturé"] = by_status.pop("saturé", 0) + by_status.pop("sature", 0)

    # Points sans adresse (données incomplètes)
    no_address = (
        db.query(func.count(db_models.CollectionPoint.id))
        .filter(
            (db_models.CollectionPoint.address == None)
            | (db_models.CollectionPoint.address == "")
        )
        .scalar() or 0
    )

    # Points sans horaires
    no_hours = (
        db.query(func.count(db_models.CollectionPoint.id))
        .filter(
            (db_models.CollectionPoint.hours == None)
            | (db_models.CollectionPoint.hours == "")
        )
        .scalar() or 0
    )

    return {
        "total":            total,
        "verified":         verified,
        "unverified":       unverified,
        "verification_rate": round(verified / total * 100, 1) if total else 0,
        "by_status":        by_status,
        "data_quality": {
            "missing_address": no_address,
            "missing_hours":   no_hours,
            "completeness_pct": round(
                ((total - no_address - no_hours) / (total * 2) * 100) if total else 0, 1
            ),
        },
    }


@router.put(
    "/collection-points/{point_id}/verify",
    summary="[F2] Vérifier / invalider un point de collecte",
)
async def verify_collection_point(
    point_id:  int,
    verified:  bool = True,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Marque un point de collecte comme vérifié (ou non) par l'intercommunalité.
    Garantit la fiabilité de la base de données territoriale.
    """
    point = db.query(db_models.CollectionPoint).filter(
        db_models.CollectionPoint.id == point_id
    ).first()
    if not point:
        raise HTTPException(status_code=404, detail="Point de collecte introuvable")

    point.is_verified = verified
    db.commit()
    db.refresh(point)
    return {
        "message":     f"Point {'vérifié' if verified else 'marqué non vérifié'} avec succès",
        "id":          point.id,
        "name":        point.name,
        "is_verified": point.is_verified,
    }


@router.put(
    "/collection-points/{point_id}/update-info",
    summary="[F2] Mettre à jour les informations d'un point de collecte",
)
async def update_collection_point_info(
    point_id: int,
    name:     Optional[str] = None,
    address:  Optional[str] = None,
    hours:    Optional[str] = None,
    types:    Optional[str] = None,
    status:   Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Met à jour les informations descriptives d'un point de collecte
    pour maintenir la base de données à jour (adresse, horaires, types, statut).
    """
    point = db.query(db_models.CollectionPoint).filter(
        db_models.CollectionPoint.id == point_id
    ).first()
    if not point:
        raise HTTPException(status_code=404, detail="Point de collecte introuvable")

    if name    is not None: point.name    = name
    if address is not None: point.address = address
    if hours   is not None: point.hours   = hours
    if types   is not None: point.types   = types
    if status  is not None: point.status  = status

    db.commit()
    db.refresh(point)
    return {
        "message": "Informations mises à jour",
        "id":      point.id,
        "name":    point.name,
        "address": point.address,
        "hours":   point.hours,
        "status":  point.status,
    }


# ══════════════════════════════════════════════════════════════════════════════
# FONCTION 3 : COORDINATION DES ACTEURS LOCAUX
# Coordonner les acteurs locaux (gestionnaires, prestataires, éducateurs),
# afin d'optimiser la politique de tri sur le territoire.
# ══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/actors",
    summary="[F3] Liste des acteurs locaux à coordonner",
)
async def list_actors(
    role: Optional[str] = Query(
        None,
        description="Filtrer par rôle : pointManager / collector / educator",
    ),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Retourne la liste complète des acteurs locaux :
    - Gestionnaires de points de collecte (pointManager)
    - Prestataires de collecte (collector)
    - Éducateurs environnementaux (educator)
    Permet à l'intercommunalité de connaître et coordonner ses partenaires.
    """
    coordinated_roles = ["pointManager", "collector", "educator"]
    q = db.query(db_models.User).filter(
        db_models.User.role.in_(coordinated_roles),
        db_models.User.is_active == True,
    )
    if role and role in coordinated_roles:
        q = q.filter(db_models.User.role == role)

    users = q.order_by(db_models.User.role, db_models.User.full_name).all()
    return [
        {
            "id":         u.id,
            "full_name":  u.full_name,
            "email":      u.email,
            "role":       u.role,
            "avatar_url": u.avatar_url or "",
            "created_at": u.created_at.isoformat() if u.created_at else None,
        }
        for u in users
    ]


@router.get(
    "/actors/overview",
    summary="[F3] Vue d'ensemble des acteurs par rôle",
)
async def actors_overview(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Synthèse de la répartition des acteurs locaux par rôle.
    Aide l'intercommunalité à identifier les manques de couverture sur son territoire.
    """
    counts = {}
    for role in ("pointManager", "collector", "educator"):
        counts[role] = (
            db.query(func.count(db_models.User.id))
            .filter(db_models.User.role == role, db_models.User.is_active == True)
            .scalar() or 0
        )

    # Signalements en attente (besoin de gestionnaires)
    from app.reports.models import CitizenReport
    pending_reports = (
        db.query(func.count(CitizenReport.id))
        .filter(CitizenReport.status == "pending")
        .scalar() or 0
    )

    # Tournées en cours (collecteurs actifs)
    from app.collector_routes.models import CollectionRoute
    active_routes = (
        db.query(func.count(CollectionRoute.id))
        .filter(CollectionRoute.status == "in_progress")
        .scalar() or 0
    )

    return {
        "actors_count":    counts,
        "total_actors":    sum(counts.values()),
        "coordination": {
            "pending_reports":      pending_reports,
            "active_collection_routes": active_routes,
            "alert": (
                "⚠️ Des signalements sont en attente sans gestionnaire disponible"
                if pending_reports > 0 and counts["pointManager"] == 0
                else None
            ),
        },
    }


@router.post(
    "/actors/notify",
    summary="[F3] Envoyer une notification à un groupe d'acteurs",
)
async def notify_actors(
    roles:   List[str],
    title:   str,
    message: str,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Envoie une notification in-app à tous les acteurs d'un ou plusieurs rôles.
    Permet à l'intercommunalité de diffuser des instructions ou alertes
    à ses partenaires (gestionnaires, collecteurs, éducateurs).
    """
    valid_roles = {"pointManager", "collector", "educator"}
    roles_to_notify = [r for r in roles if r in valid_roles]
    if not roles_to_notify:
        raise HTTPException(
            status_code=400,
            detail=f"Rôles invalides. Valeurs acceptées : {list(valid_roles)}",
        )

    users = db.query(db_models.User).filter(
        db_models.User.role.in_(roles_to_notify),
        db_models.User.is_active == True,
    ).all()

    notified = 0
    for u in users:
        notif = db_models.Notification(
            user_id        = u.id,
            type           = "intercommunality_message",
            title          = title,
            body           = message,
            from_user_name = current_user.full_name,
            is_read        = False,
        )
        db.add(notif)
        notified += 1
    db.commit()

    # ── Push FCM système (barre de notifications) ──────────────────────────
    try:
        from services.fcm_push_service import send_push_to_user as _fcm_push
        for u in users:
            _fcm_push(
                db, u.id, title, message,
                data={"type": "intercommunality_message", "from": str(current_user.id)},
            )
    except Exception as _e:
        pass  # Non bloquant — la notification in-app est déjà enregistrée

    return {
        "message":        f"Notification envoyée à {notified} acteur(s)",
        "notified_count": notified,
        "roles_targeted": roles_to_notify,
    }


@router.get(
    "/actors/{actor_id}/activity",
    summary="[F3] Activité d'un acteur local",
)
async def actor_activity(
    actor_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Consulte l'activité récente d'un acteur local spécifique
    (signalements traités, tournées effectuées, vidéos publiées).
    Aide l'intercommunalité à évaluer les contributions de ses partenaires.
    """
    from app.reports.models import CitizenReport
    from app.collector_routes.models import CollectionRoute

    actor = db.query(db_models.User).filter(
        db_models.User.id == actor_id,
        db_models.User.role.in_(["pointManager", "collector", "educator"]),
    ).first()
    if not actor:
        raise HTTPException(status_code=404, detail="Acteur introuvable")

    activity = {
        "id":        actor.id,
        "full_name": actor.full_name,
        "role":      actor.role,
        "email":     actor.email,
    }

    if actor.role == "pointManager":
        resolved = (
            db.query(func.count(CitizenReport.id))
            .filter(
                CitizenReport.assigned_to == actor_id,
                CitizenReport.status == "resolved",
            )
            .scalar() or 0
        )
        pending = (
            db.query(func.count(CitizenReport.id))
            .filter(
                CitizenReport.assigned_to == actor_id,
                CitizenReport.status == "processing",
            )
            .scalar() or 0
        )
        activity["reports_resolved"] = resolved
        activity["reports_in_progress"] = pending

    elif actor.role == "collector":
        routes_done = (
            db.query(func.count(CollectionRoute.id))
            .filter(
                CollectionRoute.collector_id == actor_id,
                CollectionRoute.status == "completed",
            )
            .scalar() or 0
        )
        routes_planned = (
            db.query(func.count(CollectionRoute.id))
            .filter(
                CollectionRoute.collector_id == actor_id,
                CollectionRoute.status == "planned",
            )
            .scalar() or 0
        )
        activity["routes_completed"] = routes_done
        activity["routes_planned"]   = routes_planned

    elif actor.role == "educator":
        videos_count = (
            db.query(func.count(db_models.EducatorVideo.id))
            .filter(db_models.EducatorVideo.educator_id == actor_id)
            .scalar() or 0
        )
        activity["videos_published"] = videos_count

    return activity


# ══════════════════════════════════════════════════════════════════════════════
# TABLEAU DE BORD GLOBAL (résumé des 3 fonctions)
# ══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/dashboard",
    summary="Tableau de bord intercommunalité (synthèse des 3 fonctions)",
)
async def intercommunality_dashboard(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Vue d'ensemble des 3 fonctions :
    1/ Consignes locales → nombre actives / inactives
    2/ Points de collecte → état de la base de données
    3/ Acteurs → couverture et coordination
    """
    from app.reports.models import CitizenReport
    from app.collector_routes.models import CollectionRoute

    # ── F1 : Consignes ─────────────────────────────────────────────────────────
    active_instructions = (
        db.query(func.count(LocalInstruction.id))
        .filter(LocalInstruction.is_active == True)
        .scalar() or 0
    )
    inactive_instructions = (
        db.query(func.count(LocalInstruction.id))
        .filter(LocalInstruction.is_active == False)
        .scalar() or 0
    )

    # ── F2 : Points de collecte ────────────────────────────────────────────────
    total_points = db.query(func.count(db_models.CollectionPoint.id)).scalar() or 0
    verified_points = (
        db.query(func.count(db_models.CollectionPoint.id))
        .filter(db_models.CollectionPoint.is_verified == True)
        .scalar() or 0
    )
    saturated_points = (
        db.query(func.count(db_models.CollectionPoint.id))
        .filter(db_models.CollectionPoint.status.in_(["saturé", "sature"]))
        .scalar() or 0
    )
    pending_reports = (
        db.query(func.count(CitizenReport.id))
        .filter(CitizenReport.status == "pending")
        .scalar() or 0
    )

    # ── F3 : Acteurs ───────────────────────────────────────────────────────────
    actors_count = {}
    for role in ("pointManager", "collector", "educator"):
        actors_count[role] = (
            db.query(func.count(db_models.User.id))
            .filter(db_models.User.role == role, db_models.User.is_active == True)
            .scalar() or 0
        )
    active_routes = (
        db.query(func.count(CollectionRoute.id))
        .filter(CollectionRoute.status == "in_progress")
        .scalar() or 0
    )

    return {
        "f1_consignes": {
            "active":   active_instructions,
            "inactive": inactive_instructions,
            "total":    active_instructions + inactive_instructions,
        },
        "f2_points_de_collecte": {
            "total":             total_points,
            "verified":          verified_points,
            "unverified":        total_points - verified_points,
            "saturated":         saturated_points,
            "pending_reports":   pending_reports,
        },
        "f3_acteurs": {
            "by_role":            actors_count,
            "total":              sum(actors_count.values()),
            "active_routes":      active_routes,
        },
    }


# ══════════════════════════════════════════════════════════════════════════════
# F3 EXTENSION — MESSAGERIE INDIVIDUELLE & GROUPES SUR-MESURE
# ══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/actors/{actor_id}/notify",
    summary="[F3] Envoyer un message individuel à un acteur",
)
async def notify_individual_actor(
    actor_id: int,
    data: ActorNotifyRequest,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Envoie une notification personnelle à un acteur local précis.
    Permet à l'intercommunalité de communiquer directement avec
    un gestionnaire, collecteur ou éducateur individuel.
    """
    actor = db.query(db_models.User).filter(
        db_models.User.id == actor_id,
        db_models.User.role.in_(["pointManager", "collector", "educator"]),
        db_models.User.is_active == True,
    ).first()
    if not actor:
        raise HTTPException(status_code=404, detail="Acteur introuvable ou rôle invalide")

    notif = db_models.Notification(
        user_id        = actor.id,
        sender_id      = current_user.id,
        type           = "intercommunality_message",
        title          = data.title,
        body           = data.message,
        from_user_name = current_user.full_name,
        is_read        = False,
    )
    db.add(notif)
    db.commit()

    # ── Push FCM système ──────────────────────────────────────────────────
    try:
        from services.fcm_push_service import send_push_to_user as _fcm_push
        _fcm_push(
            db, actor.id, data.title, data.message,
            data={"type": "intercommunality_message", "from": str(current_user.id)},
        )
    except Exception:
        pass  # Non bloquant

    return {
        "message":      f"Message envoyé à {actor.full_name}",
        "recipient_id": actor.id,
        "recipient":    actor.full_name,
        "role":         actor.role,
    }


# ── Groupes d'acteurs sur-mesure ──────────────────────────────────────────────

@router.post(
    "/custom-groups",
    response_model=CustomActorGroupOut,
    status_code=201,
    summary="[F3] Créer un groupe d'acteurs personnalisé",
)
async def create_custom_group(
    data: CustomActorGroupCreate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Crée un groupe d'acteurs sur-mesure en sélectionnant des utilisateurs
    spécifiques parmi les gestionnaires, collecteurs et éducateurs.
    Ce groupe peut ensuite recevoir des notifications ciblées.
    """
    # Valider que tous les IDs sont bien des acteurs locaux
    valid_roles = {"pointManager", "collector", "educator"}
    if data.member_ids:
        members = db.query(db_models.User).filter(
            db_models.User.id.in_(data.member_ids),
            db_models.User.role.in_(valid_roles),
            db_models.User.is_active == True,
        ).all()
        found_ids = {m.id for m in members}
        invalid = set(data.member_ids) - found_ids
        if invalid:
            raise HTTPException(
                status_code=400,
                detail=f"IDs invalides ou non-acteurs : {list(invalid)}",
            )

    group = CustomActorGroup(
        name        = data.name,
        description = data.description,
        member_ids  = data.member_ids,
        created_by  = current_user.id,
    )
    db.add(group)
    db.commit()
    db.refresh(group)
    return group


@router.get(
    "/custom-groups",
    response_model=List[CustomActorGroupOut],
    summary="[F3] Lister les groupes d'acteurs personnalisés",
)
async def list_custom_groups(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """Retourne tous les groupes d'acteurs créés par l'intercommunalité."""
    return db.query(CustomActorGroup)\
        .filter(CustomActorGroup.created_by == current_user.id)\
        .order_by(CustomActorGroup.created_at.desc())\
        .all()


@router.get(
    "/custom-groups/{group_id}",
    response_model=CustomActorGroupOut,
    summary="[F3] Détails d'un groupe d'acteurs personnalisé",
)
async def get_custom_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """Retourne le détail d'un groupe, y compris les membres inclus."""
    group = db.query(CustomActorGroup).filter(
        CustomActorGroup.id == group_id,
        CustomActorGroup.created_by == current_user.id,
    ).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    return group


@router.delete(
    "/custom-groups/{group_id}",
    summary="[F3] Supprimer un groupe d'acteurs personnalisé",
)
async def delete_custom_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """Supprime définitivement un groupe personnalisé."""
    group = db.query(CustomActorGroup).filter(
        CustomActorGroup.id == group_id,
        CustomActorGroup.created_by == current_user.id,
    ).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    db.delete(group)
    db.commit()
    return {"message": f"Groupe '{group.name}' supprimé avec succès"}


@router.post(
    "/custom-groups/{group_id}/notify",
    summary="[F3] Envoyer une notification à tous les membres d'un groupe personnalisé",
)
async def notify_custom_group(
    group_id: int,
    data: GroupNotifyRequest,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """
    Diffuse une notification à tous les membres du groupe sélectionné.
    Permet à l'intercommunalité de communiquer efficacement avec
    ses équipes locales sans avoir à sélectionner chaque acteur individuellement.
    """
    group = db.query(CustomActorGroup).filter(
        CustomActorGroup.id == group_id,
        CustomActorGroup.created_by == current_user.id,
    ).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")

    member_ids = group.member_ids or []
    if not member_ids:
        return {"message": "Le groupe est vide, aucun message envoyé", "notified_count": 0}

    members = db.query(db_models.User).filter(
        db_models.User.id.in_(member_ids),
        db_models.User.is_active == True,
    ).all()

    notified = 0
    for u in members:
        notif = db_models.Notification(
            user_id        = u.id,
            sender_id      = current_user.id,
            type           = "intercommunality_group_message",
            title          = data.title,
            body           = data.message,
            from_user_name = current_user.full_name,
            is_read        = False,
        )
        db.add(notif)
        notified += 1
    db.commit()

    # ── Push FCM système pour chaque membre du groupe ─────────────────────
    try:
        from services.fcm_push_service import send_push_to_user as _fcm_push
        for u in members:
            _fcm_push(
                db, u.id, data.title, data.message,
                data={
                    "type":     "intercommunality_group_message",
                    "group_id": str(group.id),
                    "from":     str(current_user.id),
                },
            )
    except Exception:
        pass  # Non bloquant

    return {
        "message":        f"Notification envoyée aux {notified} membre(s) du groupe '{group.name}'",
        "group_id":       group.id,
        "group_name":     group.name,
        "notified_count": notified,
    }


# ════════════════════════════════════════════════════════════════════════════════
# FONCTION 5 : PILOTAGE DES COLLECTEURS
# Créer des zones territoriales et affecter des collecteurs.
# Suivi du cycle de vie : pending → in_progress → done | cancelled
# ════════════════════════════════════════════════════════════════════════════════

# ── Zones ────────────────────────────────────────────────────────────────────────

@router.get(
    "/zones",
    summary="[F5] Liste des zones territoriales",
)
async def list_zones(
    territory: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """Liste toutes les zones avec le nombre d'affectations actives."""
    q = db.query(CollectorZone)
    if territory:
        q = q.filter(CollectorZone.territory.ilike(f"%{territory}%"))
    zones = q.order_by(CollectorZone.territory, CollectorZone.name).all()

    result = []
    for zone in zones:
        active = db.query(func.count(CollectorZoneAssignment.id)).filter(
            CollectorZoneAssignment.zone_id == zone.id,
            CollectorZoneAssignment.status.in_(["pending", "in_progress"]),
        ).scalar() or 0
        result.append({
            "id":                zone.id,
            "name":              zone.name,
            "territory":         zone.territory,
            "description":       zone.description,
            "color_hex":         zone.color_hex,
            "created_by":        zone.created_by,
            "created_at":        zone.created_at,
            "updated_at":        zone.updated_at,
            "active_assignments": active,
        })
    return result


@router.post(
    "/zones",
    status_code=201,
    summary="[F5] Créer une zone territoriale",
)
async def create_zone(
    data: CollectorZoneCreate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    zone = CollectorZone(**data.dict(), created_by=current_user.id)
    db.add(zone)
    db.commit()
    db.refresh(zone)
    return {"id": zone.id, "name": zone.name, "territory": zone.territory,
            "description": zone.description, "color_hex": zone.color_hex,
            "created_by": zone.created_by, "created_at": zone.created_at,
            "updated_at": zone.updated_at, "active_assignments": 0}


@router.put(
    "/zones/{zone_id}",
    summary="[F5] Modifier une zone",
)
async def update_zone(
    zone_id: int,
    data: CollectorZoneUpdate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    zone = db.query(CollectorZone).filter(CollectorZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone introuvable")
    for field, value in data.dict(exclude_unset=True).items():
        setattr(zone, field, value)
    zone.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(zone)
    return zone


@router.delete("/zones/{zone_id}", summary="[F5] Supprimer une zone")
async def delete_zone(
    zone_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    zone = db.query(CollectorZone).filter(CollectorZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone introuvable")
    # Vérifier qu'il n'y a pas d'affectations actives
    active = db.query(func.count(CollectorZoneAssignment.id)).filter(
        CollectorZoneAssignment.zone_id == zone_id,
        CollectorZoneAssignment.status.in_(["pending", "in_progress"]),
    ).scalar() or 0
    if active > 0:
        raise HTTPException(
            status_code=409,
            detail=f"Impossible de supprimer : {active} affectation(s) active(s) dans cette zone",
        )
    db.delete(zone)
    db.commit()
    return {"message": f"Zone '{zone.name}' supprimée"}


# ── Assignments ──────────────────────────────────────────────────────────────────

@router.get(
    "/assignments",
    summary="[F5] Liste des affectations",
)
async def list_assignments(
    status:   Optional[str] = Query(None, description="pending|in_progress|done|cancelled"),
    zone_id:  Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """Liste toutes les affectations, enrichies avec noms de zone/collecteur et coords des centres."""
    import json as _json
    q = db.query(CollectorZoneAssignment)
    if status:
        q = q.filter(CollectorZoneAssignment.status == status)
    if zone_id:
        q = q.filter(CollectorZoneAssignment.zone_id == zone_id)
    assignments = q.order_by(CollectorZoneAssignment.assigned_at.desc()).all()

    result = []
    for a in assignments:
        zone      = db.query(CollectorZone).filter(CollectorZone.id == a.zone_id).first() if a.zone_id else None
        collector = db.query(db_models.User).filter(db_models.User.id == a.collector_id).first()
        assigner  = db.query(db_models.User).filter(db_models.User.id == a.assigned_by).first()

        # Enrichir avec les données des centres de tri (pour la carte mission)
        collection_points_data = []
        if a.collection_point_ids:
            try:
                point_ids = _json.loads(a.collection_point_ids)
                from app.collection_points.models import CollectionPoint
                for pid in point_ids:
                    pt = db.query(CollectionPoint).filter(CollectionPoint.id == pid).first()
                    if pt:
                        collection_points_data.append({
                            "id":      pt.id,
                            "name":    pt.name,
                            "lat":     pt.lat,
                            "lng":     pt.lng,
                            "address": pt.address,
                            "status":  pt.status,
                        })
            except Exception:
                pass

        result.append({
            "id":                     a.id,
            "zone_id":                a.zone_id,
            "zone_name":              zone.name if zone else None,
            "zone_territory":         zone.territory if zone else None,
            "zone_color":             zone.color_hex if zone else None,
            "collection_point_ids":   a.collection_point_ids,
            "target_label":           a.target_label,
            "collection_points_data": collection_points_data,
            "collector_id":           a.collector_id,
            "collector_name":         collector.full_name if collector else None,
            "collector_email":        collector.email if collector else None,
            "assigned_by":            a.assigned_by,
            "assigner_name":          assigner.full_name if assigner else None,
            "mission_message":        a.mission_message,
            "priority":               a.priority,
            "status":                 a.status,
            "due_date":               a.due_date,
            "assigned_at":            a.assigned_at,
            "completed_at":           a.completed_at,
            "collector_notes":        a.collector_notes,
        })
    return result


# ── Endpoint collecteur : mes missions ───────────────────────────────────────

@router.get(
    "/my-assignments",
    summary="[Collecteur] Mes missions assignées",
)
async def get_my_assignments(
    status: Optional[str] = Query(None, description="pending|in_progress|done|cancelled"),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Retourne les affectations du collecteur connecté.
    Accessible par les rôles : collector, intercommunality, admin, superadmin.
    Enrichi avec les coordonnées des centres de tri pour la carte.
    """
    import json as _json
    from app.collection_points.models import CollectionPoint

    # Filtrer selon le rôle — un collecteur ne voit que ses missions
    allowed = {"collector", "intercommunality", "admin", "superadmin"}
    if current_user.role not in allowed:
        raise HTTPException(status_code=403, detail="Accès réservé aux collecteurs")

    q = db.query(CollectorZoneAssignment).filter(
        CollectorZoneAssignment.collector_id == current_user.id
    )
    if status:
        q = q.filter(CollectorZoneAssignment.status == status)

    assignments = q.order_by(CollectorZoneAssignment.assigned_at.desc()).all()

    result = []
    for a in assignments:
        zone = db.query(CollectorZone).filter(CollectorZone.id == a.zone_id).first() if a.zone_id else None
        assigner = db.query(db_models.User).filter(db_models.User.id == a.assigned_by).first()

        # Construire la liste des centres avec coordonnées
        collection_points_data = []
        if a.collection_point_ids:
            try:
                point_ids = _json.loads(a.collection_point_ids)
                for pid in point_ids:
                    pt = db.query(CollectionPoint).filter(CollectionPoint.id == pid).first()
                    if pt:
                        collection_points_data.append({
                            "id":      pt.id,
                            "name":    pt.name,
                            "lat":     float(pt.lat) if pt.lat is not None else None,
                            "lng":     float(pt.lng) if pt.lng is not None else None,
                            "address": pt.address,
                            "status":  pt.status,
                            "load_level": float(pt.load_level) if pt.load_level is not None else 0.0,
                        })
            except Exception:
                pass

        result.append({
            "id":                     a.id,
            "zone_id":                a.zone_id,
            "zone_name":              zone.name if zone else None,
            "zone_color":             zone.color_hex if zone else "#4CAF50",
            "target_label":           a.target_label,
            "collection_point_ids":   a.collection_point_ids,
            "collection_points_data": collection_points_data,
            "assigner_name":          assigner.full_name if assigner else None,
            "mission_message":        a.mission_message,
            "priority":               a.priority,
            "status":                 a.status,
            "due_date":               a.due_date.isoformat() if a.due_date else None,
            "assigned_at":            a.assigned_at.isoformat() if a.assigned_at else None,
            "completed_at":           a.completed_at.isoformat() if a.completed_at else None,
            "collector_notes":        a.collector_notes,
        })
    return result


@router.post(
    "/assignments",
    status_code=201,
    summary="[F5] Affecter un collecteur ou groupe à une zone ou centre",
)
async def create_assignment(
    data: CollectorZoneAssignmentCreate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    """Crée une affectation (zone OU centres directs) et envoie une notification push."""
    import json as _json
    from app.collection_points.models import CollectionPoint

    zone = None
    target_label = None
    notif_title  = ""
    notif_body   = ""
    point_ids_json = None

    # ── Mode 1 : Affectation à une zone existante ───────────────────────────
    if data.zone_id is not None:
        zone = db.query(CollectorZone).filter(CollectorZone.id == data.zone_id).first()
        if not zone:
            raise HTTPException(status_code=404, detail="Zone introuvable")
        target_label = zone.name
        priority_label = (data.priority or "normal").upper()
        notif_title  = f"[⚠️ MISSION {priority_label}] Zone : {zone.name}"
        notif_body   = data.mission_message or f"Vous êtes affecté à la zone '{zone.name}' ({zone.territory})."

    # ── Mode 2 : Affectation directe à des centres de tri ──────────────────
    elif data.collection_point_ids:
        ids = data.collection_point_ids
        points = db.query(CollectionPoint).filter(CollectionPoint.id.in_(ids)).all()
        if not points:
            raise HTTPException(status_code=404, detail="Aucun centre de tri trouvé pour ces IDs")
        found_ids   = [p.id for p in points]
        point_names = [p.name for p in points]
        # Générer un label lisible : "CR Bardo + CR Manouba"
        target_label    = " + ".join(point_names[:3]) + ("…" if len(point_names) > 3 else "")
        point_ids_json  = _json.dumps(found_ids)
        priority_label  = (data.priority or "normal").upper()
        notif_title     = f"[⚠️ MISSION {priority_label}] {target_label}"
        notif_body      = data.mission_message or f"Mission : {target_label}"

    # ── Rétro-compat : ancien champ singulier collection_point_id ───────────
    elif data.collection_point_id is not None:
        pt = db.query(CollectionPoint).filter(CollectionPoint.id == data.collection_point_id).first()
        if not pt:
            raise HTTPException(status_code=404, detail="Centre de tri introuvable")
        target_label   = pt.name
        point_ids_json = _json.dumps([pt.id])
        notif_title    = f"[⚠️ MISSION] {pt.name}"
        notif_body     = data.mission_message or f"Mission au centre : {pt.name}"

    # Vérification du collecteur
    collector = db.query(db_models.User).filter(
        db_models.User.id == data.collector_id,
        db_models.User.role == "collector",
    ).first()
    if not collector:
        raise HTTPException(status_code=404, detail="Collecteur introuvable")

    assignment = CollectorZoneAssignment(
        zone_id=data.zone_id,
        collection_point_id=data.collection_point_id,
        collection_point_ids=point_ids_json,
        target_label=target_label,
        collector_id=data.collector_id,
        group_id=data.group_id,
        assigned_by=current_user.id,
        mission_message=data.mission_message,
        priority=data.priority or "normal",
        due_date=data.due_date,
        status="pending",
    )
    db.add(assignment)
    db.flush()

    # Target info for notifications
    target_name = target_label or "Mission"
    target_type = "Zone" if data.zone_id is not None else "Centre"

    # Collect list of user IDs to notify
    notify_user_ids = []
    if collector:
        notify_user_ids.append(collector.id)
    elif data.group_id:
        group = db.query(CustomActorGroup).filter(CustomActorGroup.id == data.group_id).first()
        if group:
            try:
                mids = group.member_ids if isinstance(group.member_ids, list) else _json.loads(group.member_ids)
                notify_user_ids.extend([int(x) for x in mids])
            except Exception:
                pass

    # Send notifications
    for uid in notify_user_ids:
        try:
            import db_models as dbm
            notif = dbm.Notification(
                user_id        = uid,
                sender_id      = current_user.id,
                type           = "assignment",
                title          = notif_title,
                body           = notif_body,
                from_user_name = current_user.full_name,
                is_read        = False,
            )
            db.add(notif)
        except Exception:
            pass

        # FCM push notification
        try:
            from services.notification_service import send_push_to_user
            send_push_to_user(
                db=db,
                user_id=uid,
                title=notif_title,
                body=notif_body,
                data={
                    "type":          "assignment",
                    "assignment_id": str(assignment.id),
                    "zone_id":       str(data.zone_id or ""),
                    "target_label":  target_label or "",
                },
            )
        except Exception:
            pass

    db.commit()
    db.refresh(assignment)

    return {
        "id":             assignment.id,
        "target_label":   target_label,
        "collector_name": collector.full_name if collector else None,
        "status":         assignment.status,
        "priority":       assignment.priority,
        "assigned_at":    assignment.assigned_at,
        "message":        f"Affectation créée pour la mission sur '{target_name}'",
    }



@router.get(
    "/assignments/{assignment_id}",
    summary="[F5/Collecteur] Détail d'une affectation",
)
async def get_assignment(
    assignment_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Retourne le détail d'une affectation avec les coordonnées des centres.
    Accessible par intercommunality/admin ou par le collecteur concerné.
    """
    import json as _json
    from app.collection_points.models import CollectionPoint

    a = db.query(CollectorZoneAssignment).filter(
        CollectorZoneAssignment.id == assignment_id
    ).first()
    if not a:
        raise HTTPException(status_code=404, detail="Affectation introuvable")

    # Autorisation : intercommunality/admin OU collecteur concerné
    allowed_roles = {"intercommunality", "admin", "superadmin"}
    if current_user.role not in allowed_roles:
        if current_user.role == "collector" and a.collector_id != current_user.id:
            raise HTTPException(status_code=403, detail="Non autorisé")
        elif current_user.role not in {"collector"}:
            raise HTTPException(status_code=403, detail="Non autorisé")

    zone = db.query(CollectorZone).filter(CollectorZone.id == a.zone_id).first() if a.zone_id else None
    collector = db.query(db_models.User).filter(db_models.User.id == a.collector_id).first()
    assigner = db.query(db_models.User).filter(db_models.User.id == a.assigned_by).first()

    collection_points_data = []
    if a.collection_point_ids:
        try:
            point_ids = _json.loads(a.collection_point_ids)
            for pid in point_ids:
                pt = db.query(CollectionPoint).filter(CollectionPoint.id == pid).first()
                if pt:
                    collection_points_data.append({
                        "id":      pt.id,
                        "name":    pt.name,
                        "lat":     float(pt.lat) if pt.lat is not None else None,
                        "lng":     float(pt.lng) if pt.lng is not None else None,
                        "address": pt.address,
                        "status":  pt.status,
                        "load_level": float(pt.load_level) if pt.load_level is not None else 0.0,
                    })
        except Exception:
            pass

    return {
        "id":                     a.id,
        "zone_id":                a.zone_id,
        "zone_name":              zone.name if zone else None,
        "zone_color":             zone.color_hex if zone else "#4CAF50",
        "target_label":           a.target_label,
        "collection_point_ids":   a.collection_point_ids,
        "collection_points_data": collection_points_data,
        "collector_id":           a.collector_id,
        "collector_name":         collector.full_name if collector else None,
        "assigned_by":            a.assigned_by,
        "assigner_name":          assigner.full_name if assigner else None,
        "mission_message":        a.mission_message,
        "priority":               a.priority,
        "status":                 a.status,
        "due_date":               a.due_date.isoformat() if a.due_date else None,
        "assigned_at":            a.assigned_at.isoformat() if a.assigned_at else None,
        "completed_at":           a.completed_at.isoformat() if a.completed_at else None,
        "collector_notes":        a.collector_notes,
    }


@router.patch(
    "/assignments/{assignment_id}/status",
    summary="[F5] Mettre à jour le statut d'une affectation",
)
async def update_assignment_status(
    assignment_id: int,
    data: CollectorZoneAssignmentUpdate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Accessible par l'intercommunalité ET le collecteur concerné."""
    a = db.query(CollectorZoneAssignment).filter(
        CollectorZoneAssignment.id == assignment_id
    ).first()
    if not a:
        raise HTTPException(status_code=404, detail="Affectation introuvable")

    # Le collecteur ne peut modifier que SES affectations
    if current_user.role == "collector" and a.collector_id != current_user.id:
        raise HTTPException(status_code=403, detail="Non autorisé")

    if data.status:
        a.status = data.status
        if data.status == "done" and not a.completed_at:
            a.completed_at = datetime.utcnow()
    if data.collector_notes is not None:
        a.collector_notes = data.collector_notes

    db.commit()
    db.refresh(a)
    return {"id": a.id, "status": a.status, "completed_at": a.completed_at}


@router.delete(
    "/assignments/{assignment_id}",
    summary="[F5] Annuler/supprimer une affectation",
)
async def delete_assignment(
    assignment_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_intercommunality),
):
    a = db.query(CollectorZoneAssignment).filter(
        CollectorZoneAssignment.id == assignment_id
    ).first()
    if not a:
        raise HTTPException(status_code=404, detail="Affectation introuvable")
    db.delete(a)
    db.commit()
    return {"message": "Affectation supprimée"}
