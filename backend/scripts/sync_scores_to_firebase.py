"""
sync_scores_to_firebase.py
---------------------------
Resynchronise tous les scores utilisateurs depuis PostgreSQL vers Firebase RTDB.

Usage :
    cd backend
    python scripts/sync_scores_to_firebase.py
    python scripts/sync_scores_to_firebase.py --user-id 16    # un seul user
    python scripts/sync_scores_to_firebase.py --dry-run       # simulation sans écriture

Pourquoi ce script ?
--------------------
Les points de quiz (quiz.py) n'étaient pas synchronisés vers Firebase.
Ce script recalcule le vrai global_score (SQL) pour chaque utilisateur et
pousse le total dans /scores/{user_id} et /utilisateurs/{qr_code}/score.
"""

import sys
import os
import argparse

# Forcer la sortie UTF-8 sur Windows
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# Ajouter le dossier backend au path Python
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Charger le .env avant tout import de db/models
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

from database import SessionLocal
import db_models as db_models
from sqlalchemy import func


def sync_all_scores(dry_run: bool = False, user_id: int = None):
    db = SessionLocal()
    try:
        # Charger les utilisateurs citoyens (role=user) avec un score > 0
        query = db.query(db_models.User).filter(
            db_models.User.role == "user",
            db_models.User.global_score > 0,
        )
        if user_id:
            query = query.filter(db_models.User.id == user_id)

        users = query.all()
        print(f"\n{'[DRY-RUN] ' if dry_run else ''}Resynchronisation de {len(users)} utilisateur(s) vers Firebase...\n")

        ok_count = 0
        fail_count = 0

        for user in users:
            score = round(float(user.global_score or 0.0), 2)
            qr = user.qr_code or ""
            print(f"  User #{user.id:4d} | {user.full_name or user.email:30s} | score SQL = {score:8.2f} | qr = {qr[:40] if qr else '(aucun)'}")

            if dry_run:
                continue

            try:
                from services.firebase_service import update_user_score
                success = update_user_score(
                    user_id      = user.id,
                    new_total    = score,
                    points_added = 0.0,   # 0 = resync, pas un nouveau gain
                    bin_type     = "resync",
                    bin_id       = "resync_script",
                    qr_code      = qr,
                )
                if success:
                    ok_count += 1
                    print(f"    → [OK] Firebase mis à jour")
                else:
                    fail_count += 1
                    print(f"    → [WARN] Firebase indisponible (mode noop)")
            except Exception as e:
                fail_count += 1
                print(f"    → [ERREUR] {e}")

        if not dry_run:
            print(f"\nRésultat : {ok_count} OK / {fail_count} erreurs")
        else:
            print(f"\n[DRY-RUN] Aucune écriture effectuée. {len(users)} utilisateur(s) concerné(s).")

    finally:
        db.close()


def main():
    parser = argparse.ArgumentParser(description="Resynchronise les scores vers Firebase RTDB")
    parser.add_argument("--dry-run", action="store_true", help="Simulation sans écriture Firebase")
    parser.add_argument("--user-id", type=int, default=None, help="Resync un seul utilisateur par ID")
    args = parser.parse_args()

    sync_all_scores(dry_run=args.dry_run, user_id=args.user_id)


if __name__ == "__main__":
    main()
