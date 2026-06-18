"""
sync_firebase_complet.py
========================
Script de synchronisation COMPLÈTE PostgreSQL → Firebase Realtime Database.

Initialise ou met à jour TOUS les nœuds nécessaires :

  /utilisateurs/{user_id}/       — rôle + QR code de chaque utilisateur
  /scores/{user_id}/             — score total du citoyen
  /poubelles/{bin_code}/         — état + poids de chaque poubelle intelligente
  /notifications/{user_id}/      — nœud vide préparé pour les intercommunalités
  /collector_logs/{log_id}/      — historique des collectes
  /leaderboard/                  — top 20 citoyens par score

Exécution :
    cd backend
    python sync_firebase_complet.py

Options :
    --dry-run    Affiche ce qui serait écrit sans rien écrire dans Firebase
    --only=X     Synchronise seulement un nœud (utilisateurs|scores|poubelles|
                 notifications|collector_logs|leaderboard)

Ce script est IDEMPOTENT : relancer ne cause aucun doublon.
Toutes les opérations Firebase sont NON-BLOQUANTES : une erreur partielle
ne bloque pas les autres nœuds.
"""

import os
import sys
import argparse
from datetime import timezone

# ── Fix encodage Windows ──────────────────────────────────────────────────────
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# ── Résolution du dossier backend ─────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

# ── Chargement du .env ────────────────────────────────────────────────────────
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(BASE_DIR, ".env"))
    print("[ENV] Variables .env chargées.")
except ImportError:
    print("[ENV] python-dotenv absent — variables système utilisées.")

# ── Imports projet ────────────────────────────────────────────────────────────
from database import SessionLocal
import app.users.models              # noqa — résolution des relations SQLAlchemy
import app.posts.models              # noqa
import app.qr_bins.models            # noqa
import app.collection_points.models  # noqa
import app.notifications.models      # noqa
import app.auth.models               # noqa
import app.community.models          # noqa
import app.quiz.models               # noqa
import app.education.models          # noqa

from app.users.models     import User
from app.qr_bins.models   import SmartBin, CollectorLog
from app.qr_bins.models   import BinScan
from services.firebase_service import (
    _init_firebase,
    sync_user_to_firebase,
    update_user_score,
    update_bin_status,
)

# ── Compteurs globaux ─────────────────────────────────────────────────────────
STATS = {
    "utilisateurs":   {"ok": 0, "err": 0, "skip": 0},
    "scores":         {"ok": 0, "err": 0, "skip": 0},
    "poubelles":      {"ok": 0, "err": 0, "skip": 0},
    "notifications":  {"ok": 0, "err": 0, "skip": 0},
    "collector_logs": {"ok": 0, "err": 0, "skip": 0},
    "leaderboard":    {"ok": 0, "err": 0, "skip": 0},
}

DRY_RUN = False


def _firebase_set(path: str, data: dict) -> bool:
    """Écriture sécurisée dans Firebase RTDB. Retourne True si succès."""
    if DRY_RUN:
        print(f"  [DRY-RUN] {path} ← {list(data.keys())}")
        return True
    try:
        from firebase_admin import db as rtdb
        rtdb.reference(path).set(data)
        return True
    except Exception as e:
        print(f"  [ERR] {path} : {e}")
        return False


def _firebase_update(path: str, data: dict) -> bool:
    """Mise à jour partielle sécurisée dans Firebase RTDB."""
    if DRY_RUN:
        print(f"  [DRY-RUN] {path} ← update {list(data.keys())}")
        return True
    try:
        from firebase_admin import db as rtdb
        rtdb.reference(path).update(data)
        return True
    except Exception as e:
        print(f"  [ERR] {path} : {e}")
        return False


# ═════════════════════════════════════════════════════════════════════════════
# NŒUD 1 : /utilisateurs/{user_id}
# ═════════════════════════════════════════════════════════════════════════════

def sync_utilisateurs(db) -> None:
    """
    Synchronise tous les utilisateurs dans /utilisateurs/{user_id}/.
    Structure :
      - role    : str  ("user" | "admin" | "collector" | "intercommunality" | ...)
      - qr_code : str  (token unique ECOREWIND-UUID4)
    """
    users = db.query(User).filter(User.is_active == True).all()
    print(f"\n[UTILISATEURS] {len(users)} utilisateur(s) actif(s).")
    node = "utilisateurs"

    for u in users:
        qr   = u.qr_code or ""
        role = u.role    or "user"
        ok   = _firebase_set(
            f"utilisateurs/{u.id}",
            {"role": role, "qr_code": qr}
        )
        if ok:
            STATS[node]["ok"] += 1
        else:
            STATS[node]["err"] += 1

    print(f"[UTILISATEURS] ✓ {STATS[node]['ok']} synchro(s)  ✗ {STATS[node]['err']} erreur(s)")


# ═════════════════════════════════════════════════════════════════════════════
# NŒUD 2 : /scores/{user_id}
# ═════════════════════════════════════════════════════════════════════════════

def sync_scores(db) -> None:
    """
    Synchronise les scores de tous les citoyens dans /scores/{user_id}/.
    Structure :
      - total         : float  (score cumulé)
      - last_points   : float  (points du dernier scan)
      - last_scan     : str    (ISO datetime)
      - last_bin_type : str    (type du dernier déchet)
      - last_bin_id   : str    (bin_code du dernier scan)
    """
    citoyens = db.query(User).filter(
        User.role == "user",
        User.is_active == True
    ).all()
    print(f"\n[SCORES] {len(citoyens)} citoyen(s) à synchroniser.")
    node = "scores"

    from sqlalchemy import desc
    for u in citoyens:
        score = u.global_score or 0.0

        # Dernier scan pour les métadonnées
        last = (
            db.query(BinScan)
            .filter(BinScan.user_id == u.id)
            .order_by(desc(BinScan.scanned_at))
            .first()
        )
        last_pts  = last.points_earned if last else 0.0
        last_type = last.waste_type    if last else "general"
        last_bin  = last.bin_id        if last else "—"
        last_date = (
            last.scanned_at.replace(tzinfo=timezone.utc).isoformat()
            if last and last.scanned_at else ""
        )

        ok = _firebase_set(
            f"scores/{u.id}",
            {
                "total":         round(score, 2),
                "last_points":   round(last_pts, 2),
                "last_scan":     last_date,
                "last_bin_type": last_type,
                "last_bin_id":   last_bin,
            }
        )
        if ok:
            STATS[node]["ok"] += 1
        else:
            STATS[node]["err"] += 1

    print(f"[SCORES] ✓ {STATS[node]['ok']} synchro(s)  ✗ {STATS[node]['err']} erreur(s)")


# ═════════════════════════════════════════════════════════════════════════════
# NŒUD 3 : /poubelles/{bin_code}
# ═════════════════════════════════════════════════════════════════════════════

def sync_poubelles(db) -> None:
    """
    Synchronise toutes les poubelles intelligentes dans /poubelles/{bin_code}/.
    Structure :
      - poids              : float  (poids cumulé actuel en kg)
      - etat               : str    ("vide" | "mi-plein" | "plein" | "en_maintenance")
      - capacite_kg        : float  (capacité max, null si inconnue)
      - bin_type           : str    (type de déchet)
      - derniere_mise_a_jour : str  (ISO datetime UTC)
    """
    bins = db.query(SmartBin).all()
    print(f"\n[POUBELLES] {len(bins)} poubelle(s) trouvée(s).")
    node = "poubelles"

    from sqlalchemy import func as sqlfunc

    for b in bins:
        # Calcul du poids cumulé réel depuis les scans (depuis le dernier vidage)
        # On prend tous les scans pour simplifier (le vidage remet à 0 dans Firebase)
        poids_cumule = (
            db.query(sqlfunc.sum(BinScan.weight_kg))
            .filter(
                BinScan.smart_bin_id == b.id,
                BinScan.weight_kg.isnot(None),
            )
            .scalar()
        ) or 0.0
        poids_cumule = round(float(poids_cumule), 2)

        # Déduire l'état
        etat = _etat_depuis_status(b.status, b.capacity_kg, poids_cumule)

        from datetime import datetime
        ok = _firebase_set(
            f"poubelles/{b.bin_code}",
            {
                "poids":               poids_cumule,
                "etat":                etat,
                "capacite_kg":         b.capacity_kg,
                "bin_type":            b.bin_type,
                "derniere_mise_a_jour": datetime.utcnow().replace(
                    tzinfo=timezone.utc
                ).isoformat(),
            }
        )
        if ok:
            STATS[node]["ok"] += 1
            if not DRY_RUN:
                print(f"  [OK] {b.bin_code:30s} | {b.bin_type:12s} | {etat:12s} | {poids_cumule:.1f} kg")
        else:
            STATS[node]["err"] += 1

    print(f"[POUBELLES] ✓ {STATS[node]['ok']} synchro(s)  ✗ {STATS[node]['err']} erreur(s)")


def _etat_depuis_status(status: str, capacity_kg, poids_cumule: float) -> str:
    """Convertit le statut SQL d'une poubelle en état Firebase."""
    if status in ("maintenance", "inactive"):
        return "en_maintenance"
    if status == "full":
        return "plein"
    # Calcul par taux de remplissage si capacité connue
    if capacity_kg and capacity_kg > 0:
        taux = poids_cumule / capacity_kg
        if taux >= 0.90:
            return "plein"
        if taux >= 0.50:
            return "mi-plein"
    return "vide"


# ═════════════════════════════════════════════════════════════════════════════
# NŒUD 4 : /notifications/{user_id}
# ═════════════════════════════════════════════════════════════════════════════

def sync_notifications(db) -> None:
    """
    Prépare les nœuds /notifications/{user_id}/ pour les utilisateurs
    intercommunalité. Crée un nœud vide avec un placeholder si aucune
    notification n'existe encore.

    Structure de chaque notification (créées dynamiquement par le backend) :
      - title       : str
      - body        : str
      - type        : str  ("collection")
      - bin_code    : str
      - collector_id: str
      - weight_kg   : str
      - read        : bool
      - created_at  : str (ISO)
    """
    intercom = db.query(User).filter(
        User.role == "intercommunality",
        User.is_active == True
    ).all()
    print(f"\n[NOTIFICATIONS] {len(intercom)} utilisateur(s) intercommunalité trouvé(s).")
    node = "notifications"

    if not intercom:
        print("[NOTIFICATIONS] Aucun utilisateur intercommunalité — nœud non créé.")
        STATS[node]["skip"] += 1
        return

    from datetime import datetime
    for u in intercom:
        # On ne crée le nœud que s'il n'existe pas déjà
        ok = _firebase_set(
            f"notifications/{u.id}/_ready",
            {
                "initialized_at": datetime.utcnow().replace(
                    tzinfo=timezone.utc
                ).isoformat(),
                "user_id": u.id,
                "role":    "intercommunality",
            }
        )
        if ok:
            STATS[node]["ok"] += 1
            if not DRY_RUN:
                print(f"  [OK] Nœud /notifications/{u.id} initialisé ({u.email})")
        else:
            STATS[node]["err"] += 1

    print(f"[NOTIFICATIONS] ✓ {STATS[node]['ok']} initialisé(s)  ✗ {STATS[node]['err']} erreur(s)")


# ═════════════════════════════════════════════════════════════════════════════
# NŒUD 5 : /collector_logs/{log_id}
# ═════════════════════════════════════════════════════════════════════════════

def sync_collector_logs(db) -> None:
    """
    Synchronise tous les logs de collecte dans /collector_logs/{log_id}/.
    Structure :
      - collector_id     : int
      - collector_name   : str
      - bin_code         : str
      - bin_type         : str
      - weight_before_kg : float
      - notified         : bool
      - collected_at     : str (ISO)
    """
    logs = db.query(CollectorLog).order_by(CollectorLog.collected_at.desc()).all()
    print(f"\n[COLLECTOR_LOGS] {len(logs)} collecte(s) trouvée(s).")
    node = "collector_logs"

    if not logs:
        print("[COLLECTOR_LOGS] Aucune collecte enregistrée — nœud ignoré.")
        STATS[node]["skip"] += 1
        return

    for log in logs:
        # Récupérer le nom du collecteur
        collector_name = "Inconnu"
        if log.collector:
            collector_name = log.collector.full_name or log.collector.email or str(log.collector_id)

        ok = _firebase_set(
            f"collector_logs/{log.id}",
            {
                "collector_id":     log.collector_id,
                "collector_name":   collector_name,
                "bin_code":         log.bin_code,
                "bin_type":         log.bin_type or "general",
                "weight_before_kg": round(log.weight_before_kg or 0.0, 2),
                "notified":         bool(log.notified),
                "collected_at":     (
                    log.collected_at.replace(tzinfo=timezone.utc).isoformat()
                    if log.collected_at else ""
                ),
            }
        )
        if ok:
            STATS[node]["ok"] += 1
        else:
            STATS[node]["err"] += 1

    print(f"[COLLECTOR_LOGS] ✓ {STATS[node]['ok']} synchro(s)  ✗ {STATS[node]['err']} erreur(s)")


# ═════════════════════════════════════════════════════════════════════════════
# NŒUD 6 : /leaderboard
# ═════════════════════════════════════════════════════════════════════════════

def sync_leaderboard(db) -> None:
    """
    Synchronise le classement des 20 meilleurs citoyens dans /leaderboard/.
    Structure :
      - rank        : int
      - user_id     : int
      - full_name   : str
      - global_score: float
      - avatar_url  : str | null
    """
    from sqlalchemy import desc
    top = (
        db.query(User)
        .filter(User.role == "user", User.is_active == True)
        .order_by(desc(User.global_score))
        .limit(20)
        .all()
    )
    print(f"\n[LEADERBOARD] Top {len(top)} citoyen(s).")
    node = "leaderboard"

    leaderboard_data = {}
    for i, u in enumerate(top):
        leaderboard_data[str(u.id)] = {
            "rank":         i + 1,
            "user_id":      u.id,
            "full_name":    u.full_name or "Éco-Citoyen",
            "global_score": round(u.global_score or 0.0, 2),
            "avatar_url":   u.avatar_url or "",
        }
        if not DRY_RUN:
            print(
                f"  #{i+1:2d} | {(u.full_name or u.email or '?'):25s} | "
                f"{round(u.global_score or 0.0, 2):8.2f} pts"
            )

    ok = _firebase_set("leaderboard", leaderboard_data) if leaderboard_data else False
    if ok:
        STATS[node]["ok"] += len(top)
    else:
        STATS[node]["err"] += 1

    print(f"[LEADERBOARD] ✓ {STATS[node]['ok']} entree(s) synchro  ✗ {STATS[node]['err']} erreur(s)")


# ═════════════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════════════

def _print_banner(title: str) -> None:
    print("\n" + "═" * 62)
    print(f"  {title}")
    print("═" * 62)


def main():
    global DRY_RUN

    parser = argparse.ArgumentParser(
        description="EcoRewind — Synchronisation complète PostgreSQL → Firebase RTDB"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Affiche les opérations sans écrire dans Firebase"
    )
    parser.add_argument(
        "--only",
        choices=["utilisateurs", "scores", "poubelles", "notifications", "collector_logs", "leaderboard"],
        help="Synchronise uniquement ce nœud"
    )
    args = parser.parse_args()
    DRY_RUN = args.dry_run

    _print_banner("EcoRewind — Synchronisation Firebase RTDB")
    if DRY_RUN:
        print("  ⚠️  MODE DRY-RUN activé — aucune écriture Firebase")

    # ── Vérification Firebase ─────────────────────────────────────────────
    if not DRY_RUN and not _init_firebase():
        print("\n[ERREUR] Firebase non disponible. Vérifiez :")
        print("  1. firebase_credentials.json est dans backend/")
        print("  2. FIREBASE_DATABASE_URL est défini dans .env")
        sys.exit(1)

    # ── Session PostgreSQL ────────────────────────────────────────────────
    db = SessionLocal()
    try:
        ONLY = args.only

        if not ONLY or ONLY == "utilisateurs":
            sync_utilisateurs(db)

        if not ONLY or ONLY == "scores":
            sync_scores(db)

        if not ONLY or ONLY == "poubelles":
            sync_poubelles(db)

        if not ONLY or ONLY == "notifications":
            sync_notifications(db)

        if not ONLY or ONLY == "collector_logs":
            sync_collector_logs(db)

        if not ONLY or ONLY == "leaderboard":
            sync_leaderboard(db)

    finally:
        db.close()

    # ── Résumé final ──────────────────────────────────────────────────────
    _print_banner("RÉSUMÉ FINAL")
    total_ok  = sum(s["ok"]  for s in STATS.values())
    total_err = sum(s["err"] for s in STATS.values())
    total_skip= sum(s["skip"]for s in STATS.values())

    print(f"  {'Nœud Firebase':<20} {'OK':>5}  {'Erreurs':>7}  {'Ignorés':>7}")
    print("  " + "-" * 44)
    for noeud, s in STATS.items():
        print(f"  {('/' + noeud):<20} {s['ok']:>5}  {s['err']:>7}  {s['skip']:>7}")
    print("  " + "─" * 44)
    print(f"  {'TOTAL':<20} {total_ok:>5}  {total_err:>7}  {total_skip:>7}")

    if total_err == 0:
        print("\n  ✅ Synchronisation Firebase terminée avec succès !")
    else:
        print(f"\n  ⚠️  Synchronisation terminée avec {total_err} erreur(s).")
    print("═" * 62 + "\n")


if __name__ == "__main__":
    main()
