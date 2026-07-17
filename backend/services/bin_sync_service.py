"""
services/bin_sync_service.py
════════════════════════════════════════════════════════════════════════════════
Service de synchronisation bidirectionnelle automatique des poubelles.

Directions :
  1. PostgreSQL → Firebase  :  status, bin_type, capacite_kg
  2. Firebase   → PostgreSQL:  poids, etat (IoT → DB si poubelle pleine)

Cycle : toutes les SYNC_INTERVAL_SECONDS secondes (defaut 300 = 5 min).

Demarre automatiquement au startup FastAPI via main.py.
Aucune intervention manuelle requise.
════════════════════════════════════════════════════════════════════════════════
"""

import asyncio
import logging
from datetime import datetime, timezone
from typing import Optional

from database import SessionLocal
import db_models as m

logger = logging.getLogger("bin_sync")

# ── Configuration ─────────────────────────────────────────────────────────────
SYNC_INTERVAL_SECONDS = 300        # sync toutes les 5 minutes
FULL_THRESHOLD        = 0.90       # poids >= 90% capacite → status "full"
HALF_THRESHOLD        = 0.50       # poids >= 50% capacite → etat "mi-plein"

# Mapping PostgreSQL status → Firebase etat
STATUS_TO_ETAT = {
    "active":      None,            # calcule depuis poids
    "full":        "plein",
    "maintenance": "en_maintenance",
    "inactive":    "en_maintenance",
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _etat_from_poids(poids_kg: float, capacity_kg: float) -> str:
    """Calcule l'etat Firebase depuis le poids actuel."""
    cap = capacity_kg or 100.0
    ratio = poids_kg / cap if cap > 0 else 0
    if ratio >= FULL_THRESHOLD:
        return "plein"
    elif ratio >= HALF_THRESHOLD:
        return "mi-plein"
    return "vide"


def _get_firebase():
    """
    Retourne le module rtdb initialise, ou None si Firebase indisponible.
    On appelle _init_firebase() pour s'assurer que l'app est initialisee,
    puis on importe directement firebase_admin.db (thread-safe).
    """
    try:
        from services.firebase_service import _init_firebase
        ok = _init_firebase()
        if not ok:
            # Verifier si l'app existe quand meme (cas: deja init dans thread principal)
            import firebase_admin
            if not firebase_admin._apps:
                return None
        from firebase_admin import db as rtdb
        return rtdb
    except Exception as e:
        logger.warning("[BinSync] Firebase init echec : %s", e)
        return None


# ── Sync principal ────────────────────────────────────────────────────────────

def sync_bins_once() -> dict:
    """
    Execute un cycle complet de synchronisation bidirectionnelle.

    Retourne un rapport { ok, errors, updated_postgres, updated_firebase, scores_pulled }.
    """
    rtdb = _get_firebase()
    if rtdb is None:
        logger.warning("[BinSync] Firebase indisponible — sync ignoree")
        return {"ok": 0, "errors": 0, "updated_postgres": 0, "updated_firebase": 0, "scores_pulled": 0}

    db = SessionLocal()
    ok = errors = updated_postgres = updated_firebase = scores_pulled = synced_retried = 0

    try:
        bins = db.query(m.SmartBin).all()

        for b in bins:
            try:
                ref = rtdb.reference("poubelles/" + b.bin_code)
                fb  = ref.get() or {}

                poids_fb   = float(fb.get("poids", 0.0))
                etat_fb    = fb.get("etat", "")
                cap        = b.capacity_kg or 100.0

                # ── Direction 1 : Firebase → PostgreSQL ─────────────────────
                # Si la poubelle IoT signale qu'elle est pleine (poids ≥ 90%)
                # et que PostgreSQL ne le sait pas encore → on met a jour.
                new_status: Optional[str] = None

                if poids_fb >= cap * FULL_THRESHOLD and b.status == "active":
                    new_status = "full"
                elif etat_fb == "en_maintenance" and b.status == "active":
                    new_status = "maintenance"
                elif poids_fb == 0.0 and b.status == "full":
                    # La poubelle vient d'etre videe par le collecteur
                    new_status = "active"

                if new_status:
                    b.status = new_status
                    db.add(b)
                    updated_postgres += 1
                    logger.info("[BinSync] %s : PostgreSQL status -> %s", b.bin_code, new_status)

                # ── Direction 2 : PostgreSQL → Firebase ─────────────────────
                # Pousse les meta-donnees et l'etat calcule vers Firebase.
                etat_cible = STATUS_TO_ETAT.get(b.status)
                if etat_cible is None:
                    etat_cible = _etat_from_poids(poids_fb, cap)

                ref.update({
                    "poids":                poids_fb,
                    "etat":                 etat_cible,
                    "bin_type":             b.bin_type,
                    "capacite_kg":          b.capacity_kg,
                    "status_sql":           b.status,
                    "derniere_sync":        datetime.now(timezone.utc).isoformat(),
                })
                updated_firebase += 1
                ok += 1

            except Exception as e:
                errors += 1
                logger.error("[BinSync] Erreur sur %s : %s", b.bin_code, e)

        db.commit()

        # ── Direction 3 : Firebase /utilisateurs scores → PostgreSQL global_score ───
        # L'Arduino met a jour directement /utilisateurs/{qr_code}/score dans Firebase
        # sans passer par l'API. Ce bloc rattrape ces mises a jour toutes les 5 min.
        #
        # FIX : Apres mise a jour PostgreSQL, on pousse aussi vers /scores/{userId}
        # pour que le stream Flutter watchScore(userId) se reveille en temps reel.
        # Sans ca, l'app Flutter ne voit jamais les points Arduino dans le widget LIVE.
        try:
            from services.firebase_service import update_user_score as _fb_push_score
            all_fb_users = rtdb.reference("utilisateurs").get() or {}
            for qr_code, fb_data in all_fb_users.items():
                if not isinstance(fb_data, dict):
                    continue
                if fb_data.get("role") != "user":
                    continue  # seuls les citoyens ont un score
                fb_score = float(fb_data.get("score", 0.0))
                if fb_score <= 0:
                    continue  # pas de score Arduino a remonter
                user = db.query(m.User).filter(m.User.qr_code == qr_code).first()
                if user and fb_score > (user.global_score or 0):
                    old_pg_score = float(user.global_score or 0)
                    arduino_delta = round(fb_score - old_pg_score, 2)
                    logger.info(
                        "[BinSync] Score Arduino remonte : user %s (%s) %s -> %s pts (+%s)",
                        user.id, qr_code[:20], old_pg_score, fb_score, arduino_delta,
                    )
                    # 1. Mettre a jour PostgreSQL (source de verite)
                    user.global_score = fb_score
                    db.add(user)
                    scores_pulled += 1
                    # 2. Pousser vers /scores/{userId} pour reveiller le stream Flutter
                    #    L'Arduino identifie BIN-GENERAL-001 comme poubelle fixe.
                    try:
                        _fb_push_score(
                            user_id      = user.id,
                            new_total    = fb_score,
                            points_added = arduino_delta,
                            bin_type     = "general",     # BIN-GENERAL-001 = dechets generaux
                            bin_id       = "BIN-GENERAL-001",
                            qr_code      = qr_code,
                        )
                        logger.info(
                            "[BinSync] Score Arduino pousse vers /scores/%d (%.1f pts)",
                            user.id, fb_score,
                        )
                    except Exception as e_push:
                        logger.warning("[BinSync] Push /scores/%d echoue : %s", user.id, e_push)
            db.commit()
        except Exception as e:
            logger.error("[BinSync] Erreur remontee scores Firebase : %s", e)

        # ── Direction 4 : Retry BinScans firebase_synced=False ───────────────
        # Si Firebase était en panne lors d'un scan, firebase_synced reste False.
        # On re-tente la sync à chaque cycle BinSync (50 max par cycle).
        try:
            from services.firebase_service import update_user_score as _fb_score
            unsynced = (
                db.query(m.BinScan)
                .filter(m.BinScan.firebase_synced == False)  # noqa: E712
                .limit(50)
                .all()
            )
            for scan in unsynced:
                user = db.query(m.User).filter(m.User.id == scan.user_id).first()
                if not user:
                    continue
                try:
                    ok_retry = _fb_score(
                        user_id      = user.id,
                        new_total    = float(user.global_score or 0),
                        points_added = float(scan.points_earned or 0),
                        bin_type     = scan.waste_type or "general",
                        bin_id       = scan.bin_id or "",   # bin_id = bin_code textuel (legacy)
                        qr_code      = user.qr_code or "",
                    )
                    if ok_retry:
                        scan.firebase_synced = True
                        db.add(scan)
                        synced_retried += 1
                        logger.info(
                            "[BinSync] Retry Firebase OK : scan #%d user %d",
                            scan.id, user.id,
                        )
                except Exception as e_retry:
                    logger.warning("[BinSync] Retry scan #%d : %s", scan.id, e_retry)
            if synced_retried:
                db.commit()
                logger.info("[BinSync] %d scan(s) re-synchronisé(s) vers Firebase.", synced_retried)
        except Exception as e:
            logger.error("[BinSync] Erreur retry firebase_synced : %s", e)

    except Exception as e:
        logger.error("[BinSync] Erreur critique : %s", e)
        errors += 1
    finally:
        db.close()

    logger.info(
        "[BinSync] Cycle termine — ok=%d err=%d pg_updated=%d fb_updated=%d retried=%d",
        ok, errors, updated_postgres, updated_firebase, synced_retried,
    )
    return {
        "ok":               ok,
        "errors":           errors,
        "updated_postgres": updated_postgres,
        "updated_firebase": updated_firebase,
        "synced_retried":   synced_retried,
        "timestamp":        datetime.now(timezone.utc).isoformat(),
    }



# ── Seed Arduino ──────────────────────────────────────────────────────────────

def _seed_arduino_bin() -> None:
    """
    Garantit que BIN-GENERAL-001 existe dans PostgreSQL.

    L'Arduino embarque utilise ce bin_code fixe (#define BIN_ID "BIN-GENERAL-001").
    Si la poubelle n'est pas encore dans la base, les scan_logs Arduino ne peuvent
    pas etre traces correctement. Cette fonction est appelee une seule fois au
    demarrage du BinSync et est totalement idempotente.
    """
    db = SessionLocal()
    try:
        existing = db.query(m.SmartBin).filter(
            m.SmartBin.bin_code == "BIN-GENERAL-001"
        ).first()

        if existing is None:
            bin_arduino = m.SmartBin(
                bin_code      = "BIN-GENERAL-001",
                bin_type      = "general",
                capacity_kg   = 2.5,        # BIN_FULL_WEIGHT_KG dans le code Arduino
                status        = "active",
                location_note = "Poubelle Arduino (seed automatique)",
            )
            db.add(bin_arduino)
            db.commit()
            logger.info("[BinSync] Seed : BIN-GENERAL-001 cree dans PostgreSQL (capacity=2.5 kg).")
        else:
            logger.debug("[BinSync] Seed : BIN-GENERAL-001 deja present (id=%d).", existing.id)
    except Exception as e:
        logger.error("[BinSync] Erreur seed BIN-GENERAL-001 : %s", e)
    finally:
        db.close()


# ── Tache asyncio (boucle infinie) ───────────────────────────────────────────

async def bin_sync_loop():
    """
    Boucle asyncio qui tourne en arriere-plan pendant toute la vie du serveur.

    - Seed BIN-GENERAL-001 au premier demarrage (idempotent).
    - Premier cycle immediatement apres le demarrage (30 s de grace).
    - Puis cycle toutes les SYNC_INTERVAL_SECONDS secondes.
    """
    logger.info("[BinSync] Service demarre. Premier cycle dans 30 secondes.")

    # Garantir que la poubelle Arduino existe en PostgreSQL
    await asyncio.to_thread(_seed_arduino_bin)

    await asyncio.sleep(30)          # laisse le temps a FastAPI de demarrer

    while True:
        try:
            result = await asyncio.to_thread(sync_bins_once)
            logger.info("[BinSync] Prochain cycle dans %d s.", SYNC_INTERVAL_SECONDS)
        except Exception as e:
            logger.error("[BinSync] Exception non geree : %s", e)

        await asyncio.sleep(SYNC_INTERVAL_SECONDS)
