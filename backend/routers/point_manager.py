"""
routers/point_manager.py — Endpoints dédiés au rôle pointManager
=================================================================
Fonctions couvertes :
  1/ Traiter les signalements des utilisateurs (anomalies : fermeture, saturation…)
  2/ Optimiser l'accessibilité des lieux de collecte

Accès : role == "pointManager" ou "admin"
"""

import json
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

import db_models as db_models
from database import get_db
from core.deps import get_current_user
from app.reports.models import CitizenReport
from app.reports.schemas import (
    CitizenReportCreate,
    CitizenReportOut,
    ReportAssign,
    ReportResolve,
    ReportReject,
)

router = APIRouter(prefix="/point-manager", tags=["point-manager"])


# ── Dépendance de rôle ────────────────────────────────────────────────────────

def _require_manager(
    current_user: db_models.User = Depends(get_current_user),
):
    if current_user.role not in ("pointManager", "admin"):
        raise HTTPException(
            status_code=403,
            detail="Accès réservé aux gestionnaires de points de collecte",
        )
    return current_user


# ── Helper : sérialiser un rapport ───────────────────────────────────────────

def _report_to_dict(r: CitizenReport) -> dict:
    return {
        "id":                    r.id,
        "collection_point_id":   r.collection_point_id,
        "collection_point_name": r.collection_point.name if r.collection_point else "—",
        "user_id":               r.user_id,
        "reporter_name":         r.reporter.full_name if r.reporter else "—",
        "report_type":           r.report_type,
        "description":           r.description,
        "photo_url":             r.photo_url,
        "status":                r.status,
        "assigned_to":           r.assigned_to,
        "assigned_manager_name": r.assigned_manager.full_name if r.assigned_manager else None,
        "resolution_note":       r.resolution_note,
        "resolved_at":           r.resolved_at.isoformat() if r.resolved_at else None,
        "created_at":            r.created_at.isoformat() if r.created_at else None,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 1. DASHBOARD GESTIONNAIRE
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/dashboard", summary="Dashboard du gestionnaire de points de collecte")
async def manager_dashboard(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    """
    Vue d'ensemble pour le gestionnaire :
    - Signalements à traiter (pending/processing)
    - État des points de collecte
    - Statistiques de traitement
    """
    # Signalements par statut
    reports_pending = (
        db.query(func.count(CitizenReport.id))
        .filter(CitizenReport.status == "pending")
        .scalar() or 0
    )
    reports_mine = (
        db.query(func.count(CitizenReport.id))
        .filter(
            CitizenReport.assigned_to == current_user.id,
            CitizenReport.status == "processing",
        )
        .scalar() or 0
    )
    reports_resolved_total = (
        db.query(func.count(CitizenReport.id))
        .filter(CitizenReport.resolved_at != None)
        .scalar() or 0
    )

    # Points de collecte par statut
    total_points = db.query(func.count(db_models.CollectionPoint.id)).scalar() or 0
    saturated = (
        db.query(func.count(db_models.CollectionPoint.id))
        .filter(db_models.CollectionPoint.status.in_(["saturé", "sature"]))
        .scalar() or 0
    )
    maintenance = (
        db.query(func.count(db_models.CollectionPoint.id))
        .filter(db_models.CollectionPoint.status == "maintenance")
        .scalar() or 0
    )

    # 5 derniers signalements non résolus
    recent_reports = (
        db.query(CitizenReport)
        .filter(CitizenReport.status.in_(["pending", "processing"]))
        .order_by(CitizenReport.created_at.desc())
        .limit(5)
        .all()
    )

    return {
        "reports": {
            "pending":        reports_pending,
            "mine_processing": reports_mine,
            "resolved_total": reports_resolved_total,
        },
        "collection_points": {
            "total":       total_points,
            "saturated":   saturated,
            "maintenance": maintenance,
            "available":   total_points - saturated - maintenance,
        },
        "recent_pending_reports": [_report_to_dict(r) for r in recent_reports],
    }


# ══════════════════════════════════════════════════════════════════════════════
# 2. SIGNALEMENTS — Consultation
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/reports", summary="Liste des signalements à traiter")
async def list_reports(
    status:      Optional[str] = Query(None, description="pending/processing/resolved/rejected"),
    report_type: Optional[str] = Query(None, description="closure/saturation/damage/inaccessible/other"),
    point_id:    Optional[int] = Query(None, description="Filtrer par point de collecte"),
    mine_only:   bool          = Query(False, description="Seulement les rapports qui me sont assignés"),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    """Retourne les signalements citoyens, filtrables par statut/type/point."""
    q = db.query(CitizenReport)
    if status:
        q = q.filter(CitizenReport.status == status)
    if report_type:
        q = q.filter(CitizenReport.report_type == report_type)
    if point_id:
        q = q.filter(CitizenReport.collection_point_id == point_id)
    if mine_only:
        q = q.filter(CitizenReport.assigned_to == current_user.id)
    reports = q.order_by(CitizenReport.created_at.desc()).all()
    return [_report_to_dict(r) for r in reports]


@router.get("/reports/{report_id}", summary="Détail d'un signalement")
async def get_report(
    report_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    r = db.query(CitizenReport).filter(CitizenReport.id == report_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    return _report_to_dict(r)


# ══════════════════════════════════════════════════════════════════════════════
# 3. SIGNALEMENTS — Traitement
# ══════════════════════════════════════════════════════════════════════════════

@router.put("/reports/{report_id}/assign", summary="Prendre en charge un signalement")
async def assign_report(
    report_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    """
    Le gestionnaire prend en charge le signalement.
    Status → processing, assigned_to → current_user.id
    """
    r = db.query(CitizenReport).filter(CitizenReport.id == report_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    if r.status not in ("pending",):
        raise HTTPException(
            status_code=409,
            detail=f"Signalement déjà en statut '{r.status}', impossible d'assigner",
        )
    r.status      = "processing"
    r.assigned_to = current_user.id
    r.updated_at  = datetime.utcnow()
    db.commit()
    db.refresh(r)

    # Notifier le citoyen
    notif = db_models.Notification(
        user_id        = r.user_id,
        type           = "report_update",
        title          = "🔧 Signalement pris en charge",
        body           = f"Votre signalement sur « {r.collection_point.name} » est en cours de traitement.",
        from_user_name = current_user.full_name,
        is_read        = False,
    )
    db.add(notif)
    db.commit()

    return {"message": "Signalement pris en charge", "report": _report_to_dict(r)}


@router.put("/reports/{report_id}/resolve", summary="Résoudre un signalement")
async def resolve_report(
    report_id: int,
    data: ReportResolve,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    """
    Marque le signalement comme résolu.
    Peut également mettre à jour automatiquement le statut du point de collecte.
    """
    r = db.query(CitizenReport).filter(CitizenReport.id == report_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    if r.status == "resolved":
        raise HTTPException(status_code=409, detail="Signalement déjà résolu")

    r.status          = "resolved"
    r.assigned_to     = current_user.id
    r.resolution_note = data.resolution_note
    r.resolved_at     = datetime.utcnow()
    r.updated_at      = datetime.utcnow()
    db.commit()
    db.refresh(r)

    # Si le type de signalement est closure/saturation → remettre le point en "disponible"
    if r.report_type in ("closure", "saturation") and r.collection_point:
        point = db.query(db_models.CollectionPoint).filter(
            db_models.CollectionPoint.id == r.collection_point_id
        ).first()
        if point and point.status in ("saturé", "sature", "maintenance"):
            point.status = "disponible"
            db.commit()

    # Notifier le citoyen
    notif = db_models.Notification(
        user_id        = r.user_id,
        type           = "report_update",
        title          = "✅ Signalement résolu",
        body           = f"Votre signalement sur « {r.collection_point.name} » a été résolu. Merci !",
        from_user_name = current_user.full_name,
        is_read        = False,
    )
    db.add(notif)
    db.commit()

    return {"message": "Signalement résolu", "report": _report_to_dict(r)}


@router.put("/reports/{report_id}/reject", summary="Rejeter un signalement")
async def reject_report(
    report_id: int,
    data: ReportReject,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    """Rejette un signalement avec un motif."""
    r = db.query(CitizenReport).filter(CitizenReport.id == report_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    if r.status in ("resolved", "rejected"):
        raise HTTPException(status_code=409, detail=f"Signalement déjà '{r.status}'")

    r.status          = "rejected"
    r.assigned_to     = current_user.id
    r.resolution_note = data.resolution_note
    r.resolved_at     = datetime.utcnow()
    r.updated_at      = datetime.utcnow()
    db.commit()
    db.refresh(r)

    # Notifier le citoyen
    notif = db_models.Notification(
        user_id        = r.user_id,
        type           = "report_update",
        title          = "❌ Signalement rejeté",
        body           = f"Votre signalement sur « {r.collection_point.name} » a été rejeté. Motif : {data.resolution_note or 'Non spécifié'}",
        from_user_name = current_user.full_name,
        is_read        = False,
    )
    db.add(notif)
    db.commit()

    return {"message": "Signalement rejeté", "report": _report_to_dict(r)}


# ══════════════════════════════════════════════════════════════════════════════
# 4. POINTS DE COLLECTE — Vue gestionnaire
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/collection-points", summary="Vue d'ensemble des points de collecte")
async def manager_collection_points(
    status: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    """
    Retourne tous les points avec leur statut, niveau de remplissage
    et nombre de signalements en attente.
    """
    q = db.query(db_models.CollectionPoint)
    if status:
        q = q.filter(db_models.CollectionPoint.status == status)
    points = q.all()

    result = []
    for p in points:
        # Compter les signalements en attente pour ce point
        pending_cnt = (
            db.query(func.count(CitizenReport.id))
            .filter(
                CitizenReport.collection_point_id == p.id,
                CitizenReport.status.in_(["pending", "processing"]),
            )
            .scalar() or 0
        )
        result.append({
            "id":              p.id,
            "name":            p.name,
            "address":         p.address or "",
            "lat":             float(p.lat),
            "lng":             float(p.lng),
            "status":          p.status or "disponible",
            "load_level":      float(p.load_level or 0.0),
            "is_verified":     p.is_verified,
            "hours":           p.hours or "",
            "types":           [t.strip() for t in (p.types or "").split(",") if t.strip()],
            "pending_reports": pending_cnt,
        })
    return result


@router.get("/accessibility", summary="Analyse d'accessibilité des points de collecte")
async def accessibility_analysis(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    """
    Identifie les points peu accessibles ou nécessitant une attention :
    - Saturation élevée (load_level > 0.80)
    - En maintenance depuis longtemps
    - Avec des signalements récurrents
    """
    points = db.query(db_models.CollectionPoint).all()
    alerts = []

    for p in points:
        issues = []
        load = float(p.load_level or 0.0)

        if load >= 0.80:
            issues.append(f"Remplissage élevé ({int(load*100)}%)")
        if p.status in ("saturé", "sature"):
            issues.append("Point saturé")
        if p.status == "maintenance":
            issues.append("En maintenance")
        if not p.is_verified:
            issues.append("Non vérifié")

        # Signalements en attente
        pending_cnt = (
            db.query(func.count(CitizenReport.id))
            .filter(
                CitizenReport.collection_point_id == p.id,
                CitizenReport.status.in_(["pending", "processing"]),
            )
            .scalar() or 0
        )
        if pending_cnt > 0:
            issues.append(f"{pending_cnt} signalement(s) en attente")

        if issues:
            alerts.append({
                "id":         p.id,
                "name":       p.name,
                "address":    p.address or "",
                "status":     p.status,
                "load_level": load,
                "issues":     issues,
                "priority":   "high" if (load >= 0.90 or p.status in ("saturé","sature")) else "medium",
            })

    # Trier par priorité puis par load_level
    alerts.sort(key=lambda x: (0 if x["priority"] == "high" else 1, -x["load_level"]))
    return {"total_alerts": len(alerts), "alerts": alerts}


@router.get("/stats", summary="Statistiques des signalements traités")
async def manager_stats(
    period_days: int = Query(30),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_manager),
):
    """Statistiques de performance du gestionnaire."""
    since = datetime.utcnow() - timedelta(days=period_days)

    total_period = (
        db.query(func.count(CitizenReport.id))
        .filter(CitizenReport.created_at >= since)
        .scalar() or 0
    )
    resolved_period = (
        db.query(func.count(CitizenReport.id))
        .filter(CitizenReport.resolved_at >= since)
        .scalar() or 0
    )
    by_me = (
        db.query(func.count(CitizenReport.id))
        .filter(
            CitizenReport.assigned_to == current_user.id,
            CitizenReport.resolved_at >= since,
        )
        .scalar() or 0
    )
    by_type = {}
    for rt in ("closure", "saturation", "damage", "inaccessible", "other"):
        by_type[rt] = (
            db.query(func.count(CitizenReport.id))
            .filter(CitizenReport.report_type == rt)
            .scalar() or 0
        )

    return {
        "period_days":       period_days,
        "total_reports":     total_period,
        "resolved":          resolved_period,
        "resolved_by_me":    by_me,
        "resolution_rate":   round(resolved_period / total_period * 100, 1) if total_period else 0,
        "by_type":           by_type,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 5. SIGNALEMENT CITOYEN (endpoint public)
# ══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/citizen/report",
    summary="Citoyen : signaler une anomalie sur un point de collecte",
    tags=["citizen", "point-manager"],
)
async def citizen_create_report(
    data: CitizenReportCreate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """
    Tout utilisateur connecté peut signaler une anomalie sur un point de collecte.
    Le signalement est automatiquement mis en statut 'pending'.
    """
    # Vérifier que le point de collecte existe
    point = db.query(db_models.CollectionPoint).filter(
        db_models.CollectionPoint.id == data.collection_point_id
    ).first()
    if not point:
        raise HTTPException(status_code=404, detail="Point de collecte introuvable")

    report = CitizenReport(
        collection_point_id = data.collection_point_id,
        user_id             = current_user.id,
        report_type         = data.report_type,
        description         = data.description,
        photo_url           = data.photo_url,
        status              = "pending",
    )
    db.add(report)

    # Si signalement de saturation → mettre à jour le statut du point
    if data.report_type == "saturation":
        point.status = "saturé"
        point.load_level = "0.95"

    db.commit()
    db.refresh(report)

    # Notifier tous les gestionnaires de ce nouveau signalement
    managers = db.query(db_models.User).filter(
        db_models.User.role.in_(("pointManager", "admin")),
        db_models.User.is_active == True,
    ).all()
    for mgr in managers:
        notif = db_models.Notification(
            user_id        = mgr.id,
            type           = "new_report",
            title          = f"🚨 Nouveau signalement : {data.report_type}",
            body           = f"Signalement sur « {point.name} » par {current_user.full_name}.",
            from_user_name = current_user.full_name,
            post_id        = report.id,
            is_read        = False,
        )
        db.add(notif)
    db.commit()

    return {
        "message":   "Signalement envoyé avec succès",
        "report_id": report.id,
        "status":    report.status,
    }


@router.get(
    "/citizen/reports",
    summary="Citoyen : mes signalements",
    tags=["citizen", "point-manager"],
)
async def citizen_my_reports(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Retourne les signalements envoyés par l'utilisateur connecté."""
    reports = (
        db.query(CitizenReport)
        .filter(CitizenReport.user_id == current_user.id)
        .order_by(CitizenReport.created_at.desc())
        .all()
    )
    return [_report_to_dict(r) for r in reports]
