import time
import json
import httpx
from typing import Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import db_models as db_models
import models as models
from database import get_db
from core.deps import get_current_user

router = APIRouter(tags=["collection_points"])

# ── Géocodage inverse (Nominatim) ─────────────────────────────────────────────
async def _reverse_geocode(lat: str, lng: str) -> str:
    """Retourne une adresse lisible (en français) depuis des coordonnées GPS."""
    try:
        url = f"https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lng}&zoom=16&addressdetails=1&accept-language=fr"
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(url, headers={"User-Agent": "EcoRewindApp/1.0"})
            if r.status_code == 200:
                data = r.json()
                addr = data.get("address", {})
                parts = [
                    addr.get("road") or addr.get("pedestrian"),
                    addr.get("suburb") or addr.get("neighbourhood"),
                    addr.get("city") or addr.get("town") or addr.get("village"),
                ]
                return ", ".join(p for p in parts if p) or data.get("display_name", "")[:80]
    except Exception:
        pass
    return ""


# ── Version timestamp ──────────────────────────────────────────────────────────
_points_version: float = time.time()


def _bump_version():
    global _points_version
    _points_version = time.time()


# ── Création automatique d'alertes centre ──────────────────────────────────────
def _create_center_alert(db: Session, point: db_models.CollectionPoint, new_status: str):
    """
    Crée une notification pour tous les admin, pointManager et collector
    lorsqu'un centre passe en état 'saturé' ou 'maintenance'.
    """
    status_labels = {
        "saturé": ("🔴 Centre Saturé", f"Le centre « {point.name} » est saturé et nécessite une collecte urgente."),
        "sature": ("🔴 Centre Saturé", f"Le centre « {point.name} » est saturé et nécessite une collecte urgente."),
        "maintenance": ("🟡 Maintenance Requise", f"Le centre « {point.name} » est en maintenance. Une intervention est nécessaire."),
    }
    if new_status.lower() not in status_labels:
        return

    title, body = status_labels[new_status.lower()]

    # Récupérer tous les utilisateurs concernés
    target_roles = ("admin", "pointManager", "collector")
    users = db.query(db_models.User).filter(
        db_models.User.role.in_(target_roles),
        db_models.User.is_active == True,
    ).all()

    for user in users:
        notif = db_models.Notification(
            user_id=user.id,
            type="center_alert",
            title=title,
            body=body,
            from_user_name="Système EcoRewind",
            post_id=point.id,   # On réutilise post_id pour stocker l'id du centre
            is_read=False,
        )
        db.add(notif)

    db.commit()


@router.get("/collection-points/version")
async def get_points_version():
    """Retourne le timestamp de la dernière mise à jour des points de tri."""
    return {
        "version": _points_version,
        "updated_at": datetime.fromtimestamp(_points_version, tz=timezone.utc).isoformat(),
    }


@router.get("/collection-points/waste-types")
async def get_waste_types():
    """Retourne la liste des types de déchets disponibles."""
    return [
        "Plastique", "Verre", "Papier", "Carton",
        "Métal", "Électronique", "Batteries", "Compost",
        "Vêtements", "Général"
    ]


def _seed(db: Session):
    if db.query(db_models.CollectionPoint).count() > 0:
        return
    initial = [
        {"name": "Ariana Nord", "lat": "36.8665", "lng": "10.1647", "is_verified": True, "types": "plastique,verre,papier", "address": "Rue de la République, Ariana", "hours": "8h-18h", "status": "disponible", "load_level": "0.45"},
        {"name": "Tunis Centre", "lat": "36.8065", "lng": "10.1815", "is_verified": False, "types": "plastique,batteries", "address": "Avenue Habib Bourguiba, Tunis", "hours": "7h-20h", "status": "disponible", "load_level": "0.85"},
        {"name": "La Marsa", "lat": "36.8782", "lng": "10.3247", "is_verified": True, "types": "plastique,verre,compost", "address": "Rue du Lac, La Marsa", "hours": "9h-17h", "status": "maintenance", "load_level": "0.0"},
        {"name": "Bardo", "lat": "36.8189", "lng": "10.1658", "is_verified": False, "types": "plastique,papier", "address": "Avenue du Bardo, Le Bardo", "hours": "8h-16h", "status": "disponible", "load_level": "0.45"},
        {"name": "Ben Arous", "lat": "36.7256", "lng": "10.2164", "is_verified": True, "types": "plastique,verre,batteries,electronique", "address": "Zone industrielle, Ben Arous", "hours": "7h-19h", "status": "disponible", "load_level": "0.72"},
        {"name": "Manouba", "lat": "36.8094", "lng": "10.0971", "is_verified": True, "types": "plastique,verre", "address": "Centre ville, Manouba", "hours": "8h-17h", "status": "disponible", "load_level": "0.30"},
        {"name": "Carthage", "lat": "36.8528", "lng": "10.3306", "is_verified": True, "types": "plastique,verre,papier,compost", "address": "Rue Hannibal, Carthage", "hours": "8h-18h", "status": "disponible", "load_level": "0.55"},
        {"name": "Lac 1", "lat": "36.8325", "lng": "10.2336", "is_verified": False, "types": "plastique,batteries", "address": "Les Berges du Lac, Tunis", "hours": "9h-20h", "status": "saturé", "load_level": "0.98"},
        {"name": "Sidi Bou Said", "lat": "36.8687", "lng": "10.3414", "is_verified": True, "types": "plastique,verre,compost", "address": "Village de Sidi Bou Said", "hours": "9h-16h", "status": "disponible", "load_level": "0.20"},
        {"name": "Hammam Lif", "lat": "36.7333", "lng": "10.1667", "is_verified": True, "types": "plastique,verre,papier,electronique", "address": "Avenue de la Plage, Hammam Lif", "hours": "7h-18h", "status": "disponible", "load_level": "0.60"},
    ]
    for p in initial:
        db.add(db_models.CollectionPoint(**p))
    db.commit()


def _to_dict(p):
    types_raw = p.types or ""
    types_list = []
    types_dict = {"disponible": [], "sature": [], "maintenance": []}

    def _normalize(lst):
        return [t.strip().capitalize() for t in lst if t.strip()]

    if types_raw.startswith("{") and types_raw.endswith("}"):
        try:
            data = json.loads(types_raw)
            types_dict["disponible"] = _normalize(data.get("disponible", []))
            types_dict["sature"] = _normalize(data.get("sature", []))
            types_dict["maintenance"] = _normalize(data.get("maintenance", []))
            types_list = list(dict.fromkeys(
                types_dict["disponible"] + types_dict["sature"] + types_dict["maintenance"]
            ))
        except json.JSONDecodeError:
            pass
    else:
        types_list = _normalize(types_raw.split(","))
        types_dict["disponible"] = types_list

    return {
        "id": p.id, "name": p.name,
        "lat": float(p.lat), "lng": float(p.lng),
        "is_verified": p.is_verified,
        "types": types_list,
        "types_detail": types_dict,
        "address": p.address or "", "hours": p.hours or "",
        "status": p.status or "disponible",
        "load_level": p.load_level or "0.0",
    }


@router.get("/collection-points")
async def list_points(type: Optional[str] = None, search: Optional[str] = None,
                      db: Session = Depends(get_db)):
    _seed(db)
    points = [_to_dict(p) for p in db.query(db_models.CollectionPoint).all()]
    if type:
        points = [p for p in points if type.lower() in p["types"]]
    if search:
        q = search.lower()
        points = [p for p in points if q in p["name"].lower() or q in p["address"].lower()]
    return points


@router.get("/admin/collection-points/alerts")
async def get_center_alerts(
    limit: int = 30,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user)
):
    """
    Retourne les alertes centres de tri (notifications de type 'center_alert')
    pour l'utilisateur courant (admin, pointManager ou collector).
    """
    if current_user.role not in ("admin", "pointManager", "collector"):
        raise HTTPException(status_code=403, detail="Accès réservé aux gestionnaires et collecteurs")

    alerts = (
        db.query(db_models.Notification)
        .filter(
            db_models.Notification.user_id == current_user.id,
            db_models.Notification.type == "center_alert",
        )
        .order_by(db_models.Notification.created_at.desc())
        .limit(limit)
        .all()
    )

    return [
        {
            "id": a.id,
            "type": a.type,
            "title": a.title,
            "body": a.body,
            "center_id": a.post_id,
            "is_read": a.is_read,
            "created_at": a.created_at.isoformat() if a.created_at else None,
        }
        for a in alerts
    ]


@router.get("/admin/collection-points/alerts/unread-count")
async def get_center_alerts_unread_count(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user)
):
    """Retourne le nombre d'alertes centres non lues."""
    if current_user.role not in ("admin", "pointManager", "collector"):
        raise HTTPException(status_code=403, detail="Accès réservé")

    count = (
        db.query(db_models.Notification)
        .filter(
            db_models.Notification.user_id == current_user.id,
            db_models.Notification.type == "center_alert",
            db_models.Notification.is_read == False,
        )
        .count()
    )
    return {"count": count}


@router.put("/admin/collection-points/alerts/read-all")
async def mark_center_alerts_read(
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user)
):
    """Marque toutes les alertes centres comme lues."""
    if current_user.role not in ("admin", "pointManager", "collector"):
        raise HTTPException(status_code=403, detail="Accès réservé")

    db.query(db_models.Notification).filter(
        db_models.Notification.user_id == current_user.id,
        db_models.Notification.type == "center_alert",
        db_models.Notification.is_read == False,
    ).update({"is_read": True})
    db.commit()
    return {"message": "Toutes les alertes marquées comme lues"}


@router.post("/admin/collection-points")
async def create_point(point: models.CollectionPointCreate, db: Session = Depends(get_db),
                       current_user: db_models.User = Depends(get_current_user)):
    if current_user.role not in ("admin", "pointManager"):
        raise HTTPException(status_code=403, detail="Réservé aux administrateurs")
    data = point.dict()
    if not data.get("address"):
        data["address"] = await _reverse_geocode(data["lat"], data["lng"])
    db_point = db_models.CollectionPoint(**data)
    db.add(db_point)
    db.commit()
    db.refresh(db_point)
    _bump_version()
    # Alerter si le centre est créé directement en statut critique
    new_status = data.get("status", "disponible")
    if new_status in ("saturé", "sature", "maintenance"):
        _create_center_alert(db, db_point, new_status)
    return _to_dict(db_point)


@router.put("/admin/collection-points/{point_id}")
async def update_point(point_id: int, update: models.CollectionPointUpdate,
                       db: Session = Depends(get_db),
                       current_user: db_models.User = Depends(get_current_user)):
    if current_user.role not in ("admin", "pointManager"):
        raise HTTPException(status_code=403, detail="Réservé aux administrateurs")
    db_point = db.query(db_models.CollectionPoint).filter(
        db_models.CollectionPoint.id == point_id).first()
    if not db_point:
        raise HTTPException(status_code=404, detail="Point de collecte non trouvé")

    update_data = update.dict(exclude_unset=True)
    old_status = db_point.status or "disponible"

    # Géocodage si position changée ou adresse vidée explicitement
    new_lat = update_data.get("lat", db_point.lat)
    new_lng = update_data.get("lng", db_point.lng)
    addr_sent = update_data.get("address", None)
    if addr_sent == "" or (("lat" in update_data or "lng" in update_data) and not db_point.address):
        update_data["address"] = await _reverse_geocode(str(new_lat), str(new_lng))

    for field, value in update_data.items():
        if value is not None:
            setattr(db_point, field, value)
    db.commit()
    db.refresh(db_point)
    _bump_version()

    # ── Déclencher les alertes si le statut change vers un état critique ──────
    new_status = update_data.get("status", old_status)
    alert_statuses = {"saturé", "sature", "maintenance"}
    if new_status.lower() in alert_statuses and new_status.lower() != old_status.lower():
        _create_center_alert(db, db_point, new_status)

    return _to_dict(db_point)


@router.post("/admin/collection-points/backfill-addresses")
async def backfill_addresses(db: Session = Depends(get_db),
                             current_user: db_models.User = Depends(get_current_user)):
    """Met à jour l'adresse de tous les centres sans adresse via géocodage inverse."""
    if current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Réservé aux administrateurs")
    points = db.query(db_models.CollectionPoint).filter(
        (db_models.CollectionPoint.address == None) |
        (db_models.CollectionPoint.address == "")
    ).all()
    updated = 0
    for p in points:
        addr = await _reverse_geocode(str(p.lat), str(p.lng))
        if addr:
            p.address = addr
            updated += 1
    db.commit()
    _bump_version()
    return {"updated": updated, "message": f"{updated} adresse(s) mise(s) à jour"}


@router.delete("/admin/collection-points/{point_id}")
async def delete_point(point_id: int, db: Session = Depends(get_db),
                       current_user: db_models.User = Depends(get_current_user)):
    if current_user.role not in ("admin", "pointManager"):
        raise HTTPException(status_code=403, detail="Réservé aux administrateurs")
    db_point = db.query(db_models.CollectionPoint).filter(
        db_models.CollectionPoint.id == point_id).first()
    if not db_point:
        raise HTTPException(status_code=404, detail="Point de collecte non trouvé")
    db.delete(db_point)
    db.commit()
    _bump_version()
    return {"message": "Point de collecte supprimé"}
