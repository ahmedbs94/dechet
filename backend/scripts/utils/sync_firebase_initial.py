import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
sync_firebase_initial.py
========================
Script de synchronisation initiale : PostgreSQL --> Firebase Realtime Database.

Ce script lit TOUTES les données existantes de PostgreSQL et les pousse dans
Firebase RTDB sous les nœuds /utilisateurs et /poubelles.

À lancer UNE SEULE FOIS (idempotent — re-lancer ne cause pas de doublon).

Exécution :
    cd backend
    python sync_firebase_initial.py

Prérequis :
    - Le fichier firebase_credentials.json doit exister dans le dossier backend/
    - La variable FIREBASE_DATABASE_URL doit être définie dans .env
    - La base PostgreSQL (ou SQLite) doit être accessible
"""

import os
import sys

# Fix encodage Windows (PowerShell / cp1252)
if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

# ── Résolution du dossier backend ──────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

# ── Chargement des variables d'environnement (.env) ────────────────────────
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(BASE_DIR, ".env"))
    print("[ENV] Variables .env chargées.")
except ImportError:
    print("[ENV] python-dotenv absent — variables d'environnement système utilisées.")

# ── Imports projet ──────────────────────────────────────────────────────────
# IMPORTANT : tous les modèles liés doivent être importés AVANT la première
# requête SQLAlchemy pour que les relationships soient résolues correctement.
from database import SessionLocal

# Chargement de tous les modèles pour résoudre les relations SQLAlchemy
import app.users.models          # User (posts, saved_posts, likes)
import app.posts.models          # Post, SavedPost, Like
import app.qr_bins.models        # SmartBin, BinScan
import app.collection_points.models  # CollectionPoint (si existe)

from app.users.models import User
from app.qr_bins.models import SmartBin
from services.firebase_service import (
    sync_user_to_firebase,
    update_bin_status,
    _init_firebase,
)


def _etat_depuis_status(status: str, capacity_kg: float | None) -> str:
    """
    Convertit le statut PostgreSQL d'une poubelle en état Firebase.
    - maintenance / inactive  → "en_maintenance"
    - full                    → "plein"
    - active + pas de capacité → "vide" (état initial inconnu)
    """
    if status in ("maintenance", "inactive"):
        return "en_maintenance"
    if status == "full":
        return "plein"
    return "vide"


def sync_utilisateurs(db) -> tuple[int, int]:
    """
    Lit tous les utilisateurs de PostgreSQL et les pousse dans /utilisateurs.
    Le champ "score" est inclus UNIQUEMENT pour les citoyens (role="user").
    Retourne (nb_ok, nb_erreur).
    """
    users = db.query(User).all()
    print(f"\n[UTILISATEURS] {len(users)} utilisateur(s) trouvé(s) dans PostgreSQL.")
    ok = 0
    err = 0
    for user in users:
        qr   = user.qr_code  or ""
        role = user.role     or "user"
        name = user.full_name or ""
        mail = user.email    or ""
        score = getattr(user, 'global_score', 0) or 0
        success = sync_user_to_firebase(
            user.id, role, qr,
            full_name=name,
            email=mail,
            score=score,
        )
        if success:
            ok += 1
        else:
            err += 1
            print(f"  [!] Échec pour user #{user.id} ({user.email})")
    print(f"[UTILISATEURS] ✓ {ok} synchronisé(s)  ✗ {err} échec(s)")
    return ok, err


def sync_poubelles(db) -> tuple[int, int]:
    """
    Lit toutes les poubelles de PostgreSQL et les pousse dans /poubelles.
    Poids initial = 0.0 kg (inconnu au départ).
    Retourne (nb_ok, nb_erreur).
    """
    bins = db.query(SmartBin).all()
    print(f"\n[POUBELLES] {len(bins)} poubelle(s) trouvée(s) dans PostgreSQL.")
    ok = 0
    err = 0
    for b in bins:
        etat = _etat_depuis_status(b.status or "active", b.capacity_kg)
        # Poids initial inconnu → 0.0 kg
        success = update_bin_status(b.bin_code, poids=0.0, etat=etat)
        if success:
            ok += 1
        else:
            err += 1
            print(f"  [!] Échec pour poubelle #{b.id} ({b.bin_code})")
    print(f"[POUBELLES] ✓ {ok} synchronisée(s)  ✗ {err} échec(s)")
    return ok, err


def main():
    print("=" * 60)
    print("  EcoRewind -- Synchronisation initiale PostgreSQL -> Firebase")
    print("=" * 60)

    # Verification Firebase
    if not _init_firebase():
        print("\n[ERREUR] Firebase non disponible. Verifiez :")
        print("  1. Le fichier firebase_credentials.json est dans backend/")
        print("  2. FIREBASE_DATABASE_URL est defini dans .env")
        sys.exit(1)

    db = SessionLocal()
    try:
        u_ok, u_err = sync_utilisateurs(db)
        b_ok, b_err = sync_poubelles(db)
    finally:
        db.close()

    print("\n" + "=" * 60)
    print("  RESUME FINAL")
    print("=" * 60)
    print(f"  /utilisateurs : {u_ok} OK  /  {u_err} erreur(s)")
    print(f"  /poubelles    : {b_ok} OK  /  {b_err} erreur(s)")

    if u_err == 0 and b_err == 0:
        print("\n  [OK] Synchronisation complete avec succes !")
    else:
        print("\n  [!] Synchronisation terminee avec des erreurs.")
        print("      Verifiez les logs ci-dessus.")

    print("=" * 60)


if __name__ == "__main__":
    main()
