"""
routers/qr_bins.py — QR Poubelle Intelligente + Attribution de Score
══════════════════════════════════════════════════════════════════════
Endpoints publics / citoyen :
  POST /qr/scan-bin          → Scan d'une poubelle, validation, calcul et attribution des points
  GET  /qr/scan-history      → Historique des scans du citoyen connecté
  GET  /qr/leaderboard       → Classement des citoyens par score

Endpoints admin (smart_bins CRUD) :
  GET    /qr/smart-bins              → Liste toutes les poubelles
  POST   /qr/smart-bins              → Créer une nouvelle poubelle
  GET    /qr/smart-bins/{bin_id}     → Détail d'une poubelle
  PATCH  /qr/smart-bins/{bin_id}     → Modifier statut / infos
  DELETE /qr/smart-bins/{bin_id}     → Supprimer (désactiver)
  GET    /qr/bin-stats               → Statistiques globales (admin)
  GET    /qr/smart-bins/{bin_id}/stats → Stats d'un bac précis (admin)

Flux QR sécurisé :
  Flutter scanne bin_code
       ↓
  POST /qr/scan-bin { bin_code, qr_code, [weight_kg] }
       ↓
  1. Vérifie smart_bins.bin_code  → 404 si inconnu
  2. Vérifie smart_bins.status == "active"  → 409 si hors service
  3. Identifie citoyen via users.qr_code    → 404 si inconnu
  4. Anti double-scan 60 s                  → 429 si trop tôt
  5. Calcule points (type vient du bac)
  6. Met à jour users.global_score (SQL)
  7. Projette sur Firebase RTDB (temps réel)
  8. Crée bin_scans (smart_bin_id + bin_id legacy)
"""

from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from sqlalchemy import func, desc

import db_models as db_models
from database import get_db
from core.deps import get_current_user, get_admin_user
from services.firebase_service import (
    calculate_points, update_user_score, WASTE_POINTS
)

router = APIRouter(tags=["qr-bins"])


# ── Constantes ───────────────────────────────────────────────────────────────

DOUBLE_SCAN_WINDOW_SECONDS = 60   # Anti double-scan : 60 secondes
VALID_STATUSES = {"active", "inactive", "maintenance", "full"}
VALID_BIN_TYPES = {
    "plastique", "verre", "papier", "carton", "metal",
    "organique", "electronique", "textile", "general",
}


# ── Pydantic Schemas ──────────────────────────────────────────────────────────

class BinScanRequest(BaseModel):
    """Payload envoyé par la poubelle intelligente lors du scan QR."""
    bin_code: str = Field(..., description="Code unique de la poubelle (inscrit sur le QR)")
    qr_code: str  = Field(..., description="QR code personnel du citoyen")
    weight_kg: Optional[float] = Field(None, description="Poids en kg si la poubelle pèse les déchets")


class BinScanResponse(BaseModel):
    success: bool
    user_id: int
    user_name: str
    bin_code: str
    bin_type: str
    collection_point_id: Optional[int]
    points_earned: float
    score_before: float
    score_after: float
    firebase_synced: bool
    message: str


class SmartBinCreate(BaseModel):
    """Payload pour créer une poubelle intelligente."""
    bin_code:            str            = Field(..., description="Code QR unique ex: BIN-VERRE-A4F2")
    bin_type:            str            = Field("general", description="Type de déchet accepté")
    collection_point_id: Optional[int] = Field(None, description="ID du point de collecte rattaché")
    capacity_kg:         Optional[float] = None
    location_note:       Optional[str]  = None
    status:              str            = Field("active", description="active|inactive|maintenance|full")


class SmartBinUpdate(BaseModel):
    """Payload pour mettre à jour partiellement une poubelle."""
    bin_type:            Optional[str]  = None
    collection_point_id: Optional[int]  = None
    capacity_kg:         Optional[float] = None
    location_note:       Optional[str]  = None
    status:              Optional[str]  = None


# ── POST /qr/scan-bin ─────────────────────────────────────────────────────────

@router.post("/qr/scan-bin", response_model=BinScanResponse)
async def scan_bin(data: BinScanRequest, db: Session = Depends(get_db)):
    """
    Endpoint principal appelé par la poubelle intelligente.

    Garanties transactionnelles :
    ┌─────────────────────────────────────────────────────┐
    │  BEGIN TRANSACTION                                  │
    │    lire users.global_score                          │
    │    calculer points                                  │
    │    UPDATE users.global_score = score_after          │
    │    INSERT bin_scans (firebase_synced = False)       │
    │  COMMIT  ← score + historique toujours cohérents   │
    └─────────────────────────────────────────────────────┘
    Après COMMIT (hors transaction) :
      → sync Firebase RTDB
      → UPDATE bin_scans.firebase_synced = True  (si OK)

    Sécurité supplémentaire :
    • Vérifie bin_code dans smart_bins (rejet des QR falsifiés)
    • Vérifie status = 'active' (désactivation possible côté admin)
    • Identifie le citoyen via qr_code personnel
    • Anti double-scan 60 s sur (user_id, smart_bin_id)
    """
    bin_code = data.bin_code.strip()
    qr_code  = data.qr_code.strip()

    if not bin_code or not qr_code:
        raise HTTPException(status_code=400, detail="bin_code et qr_code sont requis")

    # ── 1. Valider la poubelle ────────────────────────────────────────────────
    smart_bin = (
        db.query(db_models.SmartBin)
        .filter(db_models.SmartBin.bin_code == bin_code)
        .first()
    )
    if not smart_bin:
        raise HTTPException(
            status_code=404,
            detail=f"Poubelle inconnue — bin_code '{bin_code}' non enregistre",
        )
    if smart_bin.status != "active":
        status_msg = {
            "inactive":    "Poubelle desactivee",
            "maintenance": "Poubelle en maintenance",
            "full":        "Poubelle pleine — veuillez en utiliser une autre",
        }.get(smart_bin.status, f"Poubelle hors service ({smart_bin.status})")
        raise HTTPException(status_code=409, detail=status_msg)

    # ── 2. Identifier le citoyen ──────────────────────────────────────────────
    user = db.query(db_models.User).filter(db_models.User.qr_code == qr_code).first()
    if not user:
        raise HTTPException(status_code=404, detail="QR citoyen invalide — utilisateur non trouve")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Compte citoyen desactive")

    # ── 3. Anti double-scan (60 secondes) ────────────────────────────────────
    cutoff = datetime.utcnow() - timedelta(seconds=DOUBLE_SCAN_WINDOW_SECONDS)
    recent = (
        db.query(db_models.BinScan)
        .filter(
            db_models.BinScan.user_id      == user.id,
            db_models.BinScan.smart_bin_id == smart_bin.id,
            db_models.BinScan.scanned_at   >= cutoff,
        )
        .first()
    )
    if recent:
        elapsed  = (datetime.utcnow() - recent.scanned_at).total_seconds()
        wait_sec = max(int(DOUBLE_SCAN_WINDOW_SECONDS - elapsed), 1)
        raise HTTPException(
            status_code=429,
            detail=f"Scan trop rapproche — reessayez dans {wait_sec} seconde(s)",
        )

    # ── 4. Calculer les points (type vient du bac, non falsifiable) ───────────
    waste_type   = smart_bin.bin_type
    points       = calculate_points(waste_type, data.weight_kg)
    score_before = user.global_score or 0.0
    score_after  = round(score_before + points, 2)

    # ════════════════════════════════════════════════════════════════════════
    # TRANSACTION SQL ATOMIQUE
    # UPDATE users + INSERT bin_scans dans le même commit.
    # Si l'une des deux opérations échoue, le rollback annule les deux.
    # firebase_synced = False pour l'instant (sync hors transaction).
    # ════════════════════════════════════════════════════════════════════════
    try:
        # 5a. Mettre à jour le score
        user.global_score = score_after
        db.add(user)

        # 5b. Créer le scan avec firebase_synced=False
        scan = db_models.BinScan(
            user_id         = user.id,
            qr_code         = qr_code,
            smart_bin_id    = smart_bin.id,
            bin_id          = bin_code,      # champ legacy conservé
            waste_type      = waste_type,
            weight_kg       = data.weight_kg,
            points_earned   = points,
            score_before    = score_before,
            score_after     = score_after,
            firebase_synced = False,         # sera mis à True après sync réussie
        )
        db.add(scan)

        db.commit()           # ← COMMIT : score + historique cohérents ensemble
        db.refresh(user)
        db.refresh(scan)

    except Exception as exc:
        db.rollback()         # ← ROLLBACK : rien n'est persisté
        raise HTTPException(
            status_code=500,
            detail=f"Erreur base de donnees — scan annule : {exc}",
        )

    # ════════════════════════════════════════════════════════════════════════
    # SYNC FIREBASE (hors transaction SQL)
    # Exécutée après COMMIT pour ne jamais bloquer la cohérence SQL.
    # Si Firebase est indisponible, le score SQL reste correct ; firebase_synced
    # reste False et sera corrigé par le job de sync periodique.
    # ════════════════════════════════════════════════════════════════════════
    firebase_ok = False
    try:
        firebase_ok = update_user_score(
            user_id     = user.id,
            new_total   = score_after,
            points_added= points,
            bin_type    = waste_type,
            bin_id      = bin_code,
        )
    except Exception:
        firebase_ok = False  # Firebase en panne : non bloquant

    # Marquer firebase_synced=True uniquement si le push a reussi
    if firebase_ok:
        try:
            scan.firebase_synced = True
            db.add(scan)
            db.commit()
        except Exception:
            db.rollback()
            # Non critique : le score SQL est correct, la sync Firebase aussi

    return BinScanResponse(
        success             = True,
        user_id             = user.id,
        user_name           = user.full_name or user.email,
        bin_code            = bin_code,
        bin_type            = waste_type,
        collection_point_id = smart_bin.collection_point_id,
        points_earned       = points,
        score_before        = score_before,
        score_after         = score_after,
        firebase_synced     = firebase_ok,
        message=(
            f"+{points} pts pour {user.full_name or user.email} "
            f"— {waste_type} @ {bin_code}"
        ),
    )


# ── GET /qr/scan-history ─────────────────────────────────────────────────────

@router.get("/qr/scan-history")
async def get_scan_history(
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Historique des scans QR du citoyen connecté."""
    scans = (
        db.query(db_models.BinScan)
        .filter(db_models.BinScan.user_id == current_user.id)
        .order_by(desc(db_models.BinScan.scanned_at))
        .limit(min(limit, 100))
        .all()
    )
    return {
        "user_id":       current_user.id,
        "total_scans":   len(scans),
        "current_score": current_user.global_score or 0.0,
        "scans": [
            {
                "id":            s.id,
                "bin_code":      s.bin_id,
                "smart_bin_id":  s.smart_bin_id,
                "waste_type":    s.waste_type,
                "weight_kg":     s.weight_kg,
                "points_earned": s.points_earned,
                "score_before":  s.score_before,
                "score_after":   s.score_after,
                "scanned_at":    s.scanned_at.isoformat() if s.scanned_at else None,
            }
            for s in scans
        ],
    }


# ── GET /qr/leaderboard ──────────────────────────────────────────────────────

@router.get("/qr/leaderboard")
async def get_leaderboard(limit: int = 10, db: Session = Depends(get_db)):
    """Classement des citoyens par score global (public)."""
    top = (
        db.query(db_models.User)
        .filter(db_models.User.is_active == True, db_models.User.role == "user")
        .order_by(desc(db_models.User.global_score))
        .limit(min(limit, 50))
        .all()
    )
    return {
        "leaderboard": [
            {
                "rank":         i + 1,
                "user_id":      u.id,
                "full_name":    u.full_name or "Citoyen",
                "avatar_url":   u.avatar_url,
                "global_score": round(u.global_score or 0.0, 2),
            }
            for i, u in enumerate(top)
        ]
    }


# ════════════════════════════════════════════════════════════════════════════
# ADMIN — Smart Bins CRUD
# ════════════════════════════════════════════════════════════════════════════

@router.get("/qr/smart-bins")
async def list_smart_bins(
    status:   Optional[str] = None,
    bin_type: Optional[str] = None,
    db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user),
):
    """Liste toutes les poubelles intelligentes avec filtres optionnels."""
    q = db.query(db_models.SmartBin)
    if status:
        q = q.filter(db_models.SmartBin.status == status)
    if bin_type:
        q = q.filter(db_models.SmartBin.bin_type == bin_type)
    bins = q.order_by(db_models.SmartBin.id).all()
    return {
        "total": len(bins),
        "smart_bins": [_serialize_bin(b) for b in bins],
    }


@router.post("/qr/smart-bins", status_code=201)
async def create_smart_bin(
    data: SmartBinCreate,
    db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user),
):
    """Créer une nouvelle poubelle intelligente."""
    # Valider bin_type
    if data.bin_type not in VALID_BIN_TYPES:
        raise HTTPException(status_code=422, detail=f"bin_type invalide. Valeurs: {sorted(VALID_BIN_TYPES)}")
    if data.status not in VALID_STATUSES:
        raise HTTPException(status_code=422, detail=f"status invalide. Valeurs: {sorted(VALID_STATUSES)}")

    # Vérifier l'unicité du bin_code
    existing = db.query(db_models.SmartBin).filter(db_models.SmartBin.bin_code == data.bin_code).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"bin_code '{data.bin_code}' déjà utilisé")

    # Vérifier que le collection_point existe (si fourni)
    if data.collection_point_id:
        cp = db.query(db_models.CollectionPoint).filter(
            db_models.CollectionPoint.id == data.collection_point_id
        ).first()
        if not cp:
            raise HTTPException(status_code=404, detail="Point de collecte introuvable")

    smart_bin = db_models.SmartBin(
        bin_code            = data.bin_code,
        bin_type            = data.bin_type,
        collection_point_id = data.collection_point_id,
        capacity_kg         = data.capacity_kg,
        location_note       = data.location_note,
        status              = data.status,
    )
    db.add(smart_bin)
    db.commit()
    db.refresh(smart_bin)
    return {"message": "Poubelle créée avec succès", "smart_bin": _serialize_bin(smart_bin)}


@router.get("/qr/smart-bins/{bin_id}")
async def get_smart_bin(
    bin_id: int,
    db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user),
):
    """Détail d'une poubelle intelligente."""
    smart_bin = db.query(db_models.SmartBin).filter(db_models.SmartBin.id == bin_id).first()
    if not smart_bin:
        raise HTTPException(status_code=404, detail="Poubelle introuvable")
    return _serialize_bin(smart_bin)


@router.patch("/qr/smart-bins/{bin_id}")
async def update_smart_bin(
    bin_id: int,
    data: SmartBinUpdate,
    db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user),
):
    """Mettre à jour partiellement une poubelle (statut, type, note…)."""
    smart_bin = db.query(db_models.SmartBin).filter(db_models.SmartBin.id == bin_id).first()
    if not smart_bin:
        raise HTTPException(status_code=404, detail="Poubelle introuvable")

    if data.status is not None:
        if data.status not in VALID_STATUSES:
            raise HTTPException(status_code=422, detail=f"status invalide: {sorted(VALID_STATUSES)}")
        smart_bin.status = data.status

    if data.bin_type is not None:
        if data.bin_type not in VALID_BIN_TYPES:
            raise HTTPException(status_code=422, detail=f"bin_type invalide: {sorted(VALID_BIN_TYPES)}")
        smart_bin.bin_type = data.bin_type

    if data.collection_point_id is not None:
        cp = db.query(db_models.CollectionPoint).filter(
            db_models.CollectionPoint.id == data.collection_point_id
        ).first()
        if not cp:
            raise HTTPException(status_code=404, detail="Point de collecte introuvable")
        smart_bin.collection_point_id = data.collection_point_id

    if data.capacity_kg is not None:
        smart_bin.capacity_kg = data.capacity_kg

    if data.location_note is not None:
        smart_bin.location_note = data.location_note

    db.commit()
    db.refresh(smart_bin)
    return {"message": "Poubelle mise à jour", "smart_bin": _serialize_bin(smart_bin)}


@router.delete("/qr/smart-bins/{bin_id}")
async def delete_smart_bin(
    bin_id: int,
    db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user),
):
    """
    Désactive une poubelle (status → inactive) au lieu de la supprimer.
    Cela préserve l'historique des scans dans bin_scans.
    Ajoutez ?hard=true pour une suppression physique (danger : perte d'historique).
    """
    smart_bin = db.query(db_models.SmartBin).filter(db_models.SmartBin.id == bin_id).first()
    if not smart_bin:
        raise HTTPException(status_code=404, detail="Poubelle introuvable")

    smart_bin.status = "inactive"
    db.commit()
    return {"message": f"Poubelle {smart_bin.bin_code} désactivée (status=inactive)"}


# ── GET /qr/bin-stats (admin — global) ──────────────────────────────────────

@router.get("/qr/bin-stats")
async def get_bin_stats(
    db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user),
):
    """Statistiques globales des scans de poubelles (admin)."""
    total_scans  = db.query(func.count(db_models.BinScan.id)).scalar() or 0
    total_points = db.query(func.sum(db_models.BinScan.points_earned)).scalar() or 0.0
    total_weight = db.query(func.sum(db_models.BinScan.weight_kg)).scalar() or 0.0
    total_bins   = db.query(func.count(db_models.SmartBin.id)).scalar() or 0
    active_bins  = db.query(func.count(db_models.SmartBin.id)).filter(
        db_models.SmartBin.status == "active"
    ).scalar() or 0

    by_type = (
        db.query(
            db_models.BinScan.waste_type,
            func.count(db_models.BinScan.id).label("count"),
            func.sum(db_models.BinScan.points_earned).label("total_points"),
        )
        .group_by(db_models.BinScan.waste_type)
        .all()
    )

    return {
        "total_scans":            total_scans,
        "total_points_distributed": round(float(total_points), 2),
        "total_weight_kg":        round(float(total_weight), 2),
        "total_smart_bins":       total_bins,
        "active_smart_bins":      active_bins,
        "waste_types_breakdown": [
            {
                "waste_type":   row.waste_type,
                "scans":        row.count,
                "total_points": round(float(row.total_points or 0), 2),
            }
            for row in by_type
        ],
        "points_scale": WASTE_POINTS,
    }


# ── GET /qr/smart-bins/{bin_id}/stats (admin — par bac) ─────────────────────

@router.get("/qr/smart-bins/{bin_id}/stats")
async def get_single_bin_stats(
    bin_id: int,
    db: Session = Depends(get_db),
    admin: db_models.User = Depends(get_admin_user),
):
    """Statistiques d'un bac précis : nombre de scans, points distribués, utilisateurs uniques."""
    smart_bin = db.query(db_models.SmartBin).filter(db_models.SmartBin.id == bin_id).first()
    if not smart_bin:
        raise HTTPException(status_code=404, detail="Poubelle introuvable")

    scans_q = db.query(db_models.BinScan).filter(db_models.BinScan.smart_bin_id == bin_id)

    total_scans    = scans_q.count()
    total_points   = db.query(func.sum(db_models.BinScan.points_earned)).filter(
        db_models.BinScan.smart_bin_id == bin_id
    ).scalar() or 0.0
    unique_users   = db.query(func.count(func.distinct(db_models.BinScan.user_id))).filter(
        db_models.BinScan.smart_bin_id == bin_id
    ).scalar() or 0
    last_scan      = scans_q.order_by(desc(db_models.BinScan.scanned_at)).first()

    return {
        "smart_bin":       _serialize_bin(smart_bin),
        "total_scans":     total_scans,
        "total_points":    round(float(total_points), 2),
        "unique_users":    unique_users,
        "last_scanned_at": last_scan.scanned_at.isoformat() if last_scan else None,
    }


# ── Sérialiseur interne ───────────────────────────────────────────────────────

def _serialize_bin(b: db_models.SmartBin) -> dict:
    return {
        "id":                 b.id,
        "bin_code":           b.bin_code,
        "bin_type":           b.bin_type,
        "collection_point_id": b.collection_point_id,
        "capacity_kg":        b.capacity_kg,
        "location_note":      b.location_note,
        "status":             b.status,
        "created_at":         b.created_at.isoformat() if b.created_at else None,
    }
