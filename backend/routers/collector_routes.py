"""
routers/collector_routes.py — Endpoints dédiés au rôle collector (prestataire de collecte)
===========================================================================================
Fonctions couvertes :
  1/ Assurer la collecte, le transport et l'orientation des déchets
  2/ Planification et suivi des tournées
  3/ Historique des collectes effectuées
  4/ Liste des poubelles/points à vider en priorité

Accès : role == "collector" ou "admin"
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
from app.collector_routes.models import CollectionRoute
from app.collector_routes.schemas import (
    CollectionRouteCreate,
    CollectionRouteUpdate,
    RouteComplete,
    CollectionRouteOut,
)

router = APIRouter(prefix="/collector", tags=["collector"])


# ── Dépendance de rôle ────────────────────────────────────────────────────────

def _require_collector(
    current_user: db_models.User = Depends(get_current_user),
):
    if current_user.role not in ("collector", "admin"):
        raise HTTPException(
            status_code=403,
            detail="Accès réservé aux prestataires de collecte",
        )
    return current_user


# ── Helper : sérialiser une tournée ──────────────────────────────────────────

def _route_to_dict(route: CollectionRoute, db: Session) -> dict:
    # Désérialiser les IDs de points
    try:
        point_ids = json.loads(route.point_ids) if route.point_ids else []
    except (json.JSONDecodeError, TypeError):
        point_ids = []

    # Récupérer les détails des points
    points_details = []
    if point_ids:
        points = db.query(db_models.CollectionPoint).filter(
            db_models.CollectionPoint.id.in_(point_ids)
        ).all()
        points_details = [
            {
                "id":         p.id,
                "name":       p.name,
                "address":    p.address or "",
                "status":     p.status or "disponible",
                "load_level": float(p.load_level or 0.0),
                "lat":        float(p.lat),
                "lng":        float(p.lng),
            }
            for p in points
        ]

    return {
        "id":              route.id,
        "collector_id":    route.collector_id,
        "collector_name":  route.collector.full_name if route.collector else "—",
        "date_planned":    route.date_planned.isoformat() if route.date_planned else None,
        "status":          route.status,
        "point_ids":       point_ids,
        "points_details":  points_details,
        "notes":           route.notes,
        "total_weight_kg": route.total_weight_kg,
        "completed_at":    route.completed_at.isoformat() if route.completed_at else None,
        "created_at":      route.created_at.isoformat() if route.created_at else None,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 1. DASHBOARD COLLECTEUR
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/dashboard", summary="Dashboard du prestataire de collecte")
async def collector_dashboard(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    """
    Vue d'ensemble pour le collecteur :
    - Tournées planifiées / en cours
    - Points prioritaires à vider
    - Historique des collectes du mois
    - Tonnage collecté
    """
    from app.qr_bins.models import CollectorLog

    # Tournées à venir
    now = datetime.utcnow()
    planned_routes = (
        db.query(func.count(CollectionRoute.id))
        .filter(
            CollectionRoute.collector_id == current_user.id,
            CollectionRoute.status == "planned",
            CollectionRoute.date_planned >= now,
        )
        .scalar() or 0
    )

    in_progress = (
        db.query(func.count(CollectionRoute.id))
        .filter(
            CollectionRoute.collector_id == current_user.id,
            CollectionRoute.status == "in_progress",
        )
        .scalar() or 0
    )

    # Collectes ce mois
    since_30 = now - timedelta(days=30)
    collectes_month = (
        db.query(func.count(CollectorLog.id))
        .filter(
            CollectorLog.collector_id == current_user.id,
            CollectorLog.collected_at >= since_30,
        )
        .scalar() or 0
    )

    # Tonnage total collecté (ce mois)
    tonnage_raw = (
        db.query(func.sum(CollectorLog.poids_avant))
        .filter(
            CollectorLog.collector_id == current_user.id,
            CollectorLog.collected_at >= since_30,
        )
        .scalar() or 0.0
    )

    # Points prioritaires (saturés ou remplissage > 80%)
    priority_points = (
        db.query(db_models.CollectionPoint)
        .filter(
            db_models.CollectionPoint.status.in_(["saturé", "sature", "full"])
        )
        .order_by(db_models.CollectionPoint.load_level.desc())
        .limit(5)
        .all()
    )

    # Prochaine tournée
    next_route = (
        db.query(CollectionRoute)
        .filter(
            CollectionRoute.collector_id == current_user.id,
            CollectionRoute.status == "planned",
            CollectionRoute.date_planned >= now,
        )
        .order_by(CollectionRoute.date_planned)
        .first()
    )

    return {
        "routes": {
            "planned":     planned_routes,
            "in_progress": in_progress,
        },
        "collectes_last_30d": collectes_month,
        "tonnage_last_30d_kg": round(float(tonnage_raw), 2),
        "priority_points": [
            {
                "id":         p.id,
                "name":       p.name,
                "address":    p.address or "",
                "status":     p.status,
                "load_level": float(p.load_level or 0.0),
                "lat":        float(p.lat),
                "lng":        float(p.lng),
            }
            for p in priority_points
        ],
        "next_route": _route_to_dict(next_route, db) if next_route else None,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 2. POUBELLES / POINTS À VIDER EN PRIORITÉ
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/bins-to-collect", summary="Points de collecte/poubelles à vider en priorité")
async def bins_to_collect(
    min_load: float = Query(0.7, description="Niveau de remplissage minimum (0.0–1.0)"),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    """
    Retourne les points de collecte et poubelles intelligentes
    qui nécessitent une collecte urgente, triés par priorité.
    """
    # Points de collecte saturés/pleins
    collection_points = db.query(db_models.CollectionPoint).filter(
        db_models.CollectionPoint.status.in_(["saturé", "sature"])
    ).all()

    # Poubelles intelligentes avec niveau élevé
    smart_bins = db.query(db_models.SmartBin).filter(
        db_models.SmartBin.is_active == True,
    ).all()

    result = {
        "collection_points": [
            {
                "id":         p.id,
                "name":       p.name,
                "address":    p.address or "",
                "lat":        float(p.lat),
                "lng":        float(p.lng),
                "status":     p.status,
                "load_level": float(p.load_level or 0.0),
                "priority":   "urgent" if float(p.load_level or 0.0) >= 0.9 else "high",
                "types":      [t.strip() for t in (p.types or "").split(",") if t.strip()],
            }
            for p in collection_points
        ],
        "smart_bins": [
            {
                "id":           b.id,
                "bin_code":     b.bin_code,
                "location":     b.location or "",
                "bin_type":     b.bin_type,
                "status":       b.status,
                "last_emptied": b.last_emptied.isoformat() if b.last_emptied else None,
                "priority":     "urgent" if b.status == "full" else "high",
            }
            for b in smart_bins
            if b.status in ("full",)
        ],
    }
    return result


# ══════════════════════════════════════════════════════════════════════════════
# 3. TOURNÉES DE COLLECTE — CRUD
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/routes", summary="Liste des tournées de collecte")
async def list_routes(
    status:    Optional[str] = Query(None, description="planned/in_progress/completed/cancelled"),
    from_date: Optional[str] = Query(None, description="Date début (YYYY-MM-DD)"),
    to_date:   Optional[str] = Query(None, description="Date fin (YYYY-MM-DD)"),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    """Liste les tournées du collecteur connecté (ou toutes si admin)."""
    q = db.query(CollectionRoute)

    # Admin voit tout, collecteur voit seulement les siennes
    if current_user.role not in ["admin", "superadmin"]:
        q = q.filter(CollectionRoute.collector_id == current_user.id)

    if status:
        q = q.filter(CollectionRoute.status == status)
    if from_date:
        try:
            q = q.filter(CollectionRoute.date_planned >= datetime.fromisoformat(from_date))
        except ValueError:
            pass
    if to_date:
        try:
            q = q.filter(CollectionRoute.date_planned <= datetime.fromisoformat(to_date))
        except ValueError:
            pass

    routes = q.order_by(CollectionRoute.date_planned.desc()).all()
    return [_route_to_dict(r, db) for r in routes]


@router.get("/routes/{route_id}", summary="Détail d'une tournée")
async def get_route(
    route_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    route = db.query(CollectionRoute).filter(CollectionRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Tournée introuvable")
    if current_user.role not in ["admin", "superadmin"] and route.collector_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé")
    return _route_to_dict(route, db)


@router.post("/routes", summary="Planifier une nouvelle tournée")
async def create_route(
    data: CollectionRouteCreate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    """Crée une tournée planifiée pour le collecteur connecté."""
    # Vérifier que les points de collecte existent
    point_ids = data.point_ids
    if point_ids:
        existing = db.query(db_models.CollectionPoint.id).filter(
            db_models.CollectionPoint.id.in_(point_ids)
        ).all()
        existing_ids = {r[0] for r in existing}
        invalid = set(point_ids) - existing_ids
        if invalid:
            raise HTTPException(
                status_code=404,
                detail=f"Points de collecte introuvables : {list(invalid)}",
            )

    route = CollectionRoute(
        collector_id = current_user.id,
        date_planned = data.date_planned,
        status       = "planned",
        point_ids    = json.dumps(point_ids),
        notes        = data.notes,
    )
    db.add(route)
    db.commit()
    db.refresh(route)
    return _route_to_dict(route, db)


@router.put("/routes/{route_id}", summary="Modifier une tournée planifiée")
async def update_route(
    route_id: int,
    data: CollectionRouteUpdate,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    route = db.query(CollectionRoute).filter(CollectionRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Tournée introuvable")
    if current_user.role not in ["admin", "superadmin"] and route.collector_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé")
    if route.status not in ("planned",):
        raise HTTPException(status_code=409, detail="Seules les tournées 'planned' peuvent être modifiées")

    if data.date_planned is not None:
        route.date_planned = data.date_planned
    if data.point_ids is not None:
        route.point_ids = json.dumps(data.point_ids)
    if data.notes is not None:
        route.notes = data.notes
    route.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(route)
    return _route_to_dict(route, db)


@router.put("/routes/{route_id}/start", summary="Démarrer une tournée")
async def start_route(
    route_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    """Passe la tournée en statut 'in_progress'."""
    route = db.query(CollectionRoute).filter(CollectionRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Tournée introuvable")
    if current_user.role not in ["admin", "superadmin"] and route.collector_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé")
    if route.status != "planned":
        raise HTTPException(status_code=409, detail=f"La tournée est déjà en statut '{route.status}'")

    route.status     = "in_progress"
    route.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(route)
    return {"message": "Tournée démarrée", "route": _route_to_dict(route, db)}


@router.put("/routes/{route_id}/complete", summary="Terminer une tournée")
async def complete_route(
    route_id: int,
    data: RouteComplete,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    """
    Marque la tournée comme terminée.
    Enregistre le tonnage total collecté et met à jour les points visités.
    Notifie l'intercommunalité via FCM.
    """
    from services.fcm_push_service import send_push_to_user

    route = db.query(CollectionRoute).filter(CollectionRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Tournée introuvable")
    if current_user.role not in ["admin", "superadmin"] and route.collector_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé")
    if route.status not in ("planned", "in_progress"):
        raise HTTPException(status_code=409, detail=f"La tournée est déjà '{route.status}'")

    route.status          = "completed"
    route.total_weight_kg = data.total_weight_kg
    route.completed_at    = datetime.utcnow()
    route.updated_at      = datetime.utcnow()
    if data.notes:
        route.notes = (route.notes or "") + f"\n[Fin de tournée] {data.notes}"
    db.commit()

    # Remettre les points visités en "disponible"
    try:
        point_ids = json.loads(route.point_ids) if route.point_ids else []
    except (json.JSONDecodeError, TypeError):
        point_ids = []

    if point_ids:
        db.query(db_models.CollectionPoint).filter(
            db_models.CollectionPoint.id.in_(point_ids),
            db_models.CollectionPoint.status.in_(["saturé", "sature"]),
        ).update(
            {"status": "disponible", "load_level": "0.1"},
            synchronize_session=False,
        )
        db.commit()

    # Notifier l'intercommunalité
    intercomm_users = db.query(db_models.User).filter(
        db_models.User.role == "intercommunality",
        db_models.User.is_active == True,
    ).all()
    for u in intercomm_users:
        notif = db_models.Notification(
            user_id        = u.id,
            type           = "collection_done",
            title          = "🚛 Tournée de collecte terminée",
            body           = (
                f"Tournée du {route.date_planned.strftime('%d/%m/%Y') if route.date_planned else '—'} "
                f"terminée par {current_user.full_name}. "
                f"Tonnage : {data.total_weight_kg or 'non renseigné'} kg."
            ),
            from_user_name = current_user.full_name,
            is_read        = False,
        )
        db.add(notif)
        # Push FCM si token disponible
        if u.fcm_token:
            try:
                await send_push_to_user(
                    u.fcm_token,
                    "🚛 Tournée terminée",
                    f"Collecte effectuée par {current_user.full_name} — {data.total_weight_kg or '?'} kg",
                )
            except Exception:
                pass
    db.commit()

    db.refresh(route)
    return {"message": "Tournée terminée avec succès", "route": _route_to_dict(route, db)}


@router.put("/routes/{route_id}/cancel", summary="Annuler une tournée")
async def cancel_route(
    route_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    route = db.query(CollectionRoute).filter(CollectionRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Tournée introuvable")
    if current_user.role not in ["admin", "superadmin"] and route.collector_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé")
    if route.status in ("completed", "cancelled"):
        raise HTTPException(status_code=409, detail=f"La tournée est déjà '{route.status}'")

    route.status     = "cancelled"
    route.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(route)
    return {"message": "Tournée annulée", "route": _route_to_dict(route, db)}


# ══════════════════════════════════════════════════════════════════════════════
# 4. HISTORIQUE DES COLLECTES (collector_logs)
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/logs", summary="Historique des collectes effectuées (QR scans + logs)")
async def collector_logs(
    period_days: int = Query(30, description="Période en jours"),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    """
    Historique complet des collectes :
    - CollectorLog (vidage de poubelles intelligentes via QR)
    - CollectionRoute (tournées complétées)
    """
    from app.qr_bins.models import CollectorLog

    since = datetime.utcnow() - timedelta(days=period_days)

    # Logs de vidage de poubelles
    logs = (
        db.query(CollectorLog)
        .filter(
            CollectorLog.collector_id == current_user.id,
            CollectorLog.collected_at >= since,
        )
        .order_by(CollectorLog.collected_at.desc())
        .all()
    )

    # Tournées complétées
    routes = (
        db.query(CollectionRoute)
        .filter(
            CollectionRoute.collector_id == current_user.id,
            CollectionRoute.status == "completed",
            CollectionRoute.completed_at >= since,
        )
        .order_by(CollectionRoute.completed_at.desc())
        .all()
    )

    return {
        "period_days": period_days,
        "bin_collections": [
            {
                "id":           log.id,
                "bin_id":       log.bin_id,
                "poids_avant":  float(log.poids_avant or 0.0),
                "collected_at": log.collected_at.isoformat() if log.collected_at else None,
            }
            for log in logs
        ],
        "routes_completed": [_route_to_dict(r, db) for r in routes],
        "summary": {
            "total_bin_collections": len(logs),
            "total_routes":          len(routes),
            "total_weight_kg":       round(
                sum(float(log.poids_avant or 0.0) for log in logs), 2
            ),
        },
    }


# ══════════════════════════════════════════════════════════════════════════════
# 5. RAPPORT DE COLLECTE — filière de recyclage
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/report", summary="Rapport de collecte pour orientation vers les filières")
async def collection_report(
    period_days: int = Query(30),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(_require_collector),
):
    """
    Rapport consolidé permettant d'orienter les déchets vers les filières de recyclage.
    Agrège par type de déchet collecté.
    """
    from app.qr_bins.models import CollectorLog

    since = datetime.utcnow() - timedelta(days=period_days)

    # Scans des poubelles intelligentes avec type de déchet
    scans = (
        db.query(
            db_models.BinScan.waste_type,
            func.count(db_models.BinScan.id).label("count"),
            func.sum(db_models.BinScan.weight_kg).label("total_kg"),
        )
        .filter(db_models.BinScan.scanned_at >= since)
        .group_by(db_models.BinScan.waste_type)
        .all()
    )

    filières = {
        "plastique":    "Valorplast / COREPLA",
        "verre":        "Calcin — verrerie",
        "papier":       "Papeterie recyclage",
        "carton":       "Papeterie recyclage",
        "metal":        "Fonderie / sidérurgie",
        "organique":    "Compostage / méthanisation",
        "electronique": "DEEE — démantèlement",
        "textile":      "Textival / tri vestimentaire",
        "general":      "Centre de tri général",
    }

    by_type = []
    total_scans = 0
    total_kg_est = 0.0

    for waste_type, count, total_kg in scans:
        wt = (waste_type or "general").lower()
        kg_est = float(total_kg or 0.0) + (count * 0.5 if not total_kg else 0)
        total_scans += count
        total_kg_est += kg_est
        by_type.append({
            "waste_type":  wt,
            "count":       count,
            "weight_kg":   round(kg_est, 2),
            "co2_saved_kg": round(kg_est * 0.5, 2),
            "filière":     filières.get(wt, "Centre de tri général"),
        })

    by_type.sort(key=lambda x: x["weight_kg"], reverse=True)

    return {
        "period_days":     period_days,
        "total_scans":     total_scans,
        "total_weight_kg": round(total_kg_est, 2),
        "co2_saved_kg":    round(total_kg_est * 0.5, 2),
        "by_waste_type":   by_type,
        "generated_at":    datetime.utcnow().isoformat(),
    }
