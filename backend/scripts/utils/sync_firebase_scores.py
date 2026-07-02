import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
sync_firebase_scores.py
========================
Synchronise les scores PostgreSQL manquants vers Firebase RTDB.
Corrige les utilisateurs qui ont un score PG > 0 mais pas de score Firebase.
"""
import os
from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import create_engine, text

db_url = os.getenv("DATABASE_URL", "")
engine = create_engine(db_url, pool_pre_ping=True)

# Importer le service Firebase
from services.firebase_service import update_user_score, get_user_score

print("=" * 60)
print("  SYNCHRONISATION SCORES PostgreSQL -> Firebase")
print("=" * 60)

# 1. Trouver les utilisateurs avec score > 0
with engine.connect() as conn:
    users = conn.execute(text(
        "SELECT id, email, global_score FROM users WHERE global_score > 0 ORDER BY id"
    )).fetchall()

print(f"\n  {len(users)} utilisateur(s) avec score > 0 dans PostgreSQL\n")

synced = 0
already_ok = 0
failed = 0

for u in users:
    uid, email, pg_score = u[0], u[1], u[2]
    
    # Verifier si deja dans Firebase
    fb_data = get_user_score(uid)
    if fb_data and abs(float(fb_data.get("total", 0)) - float(pg_score)) < 0.01:
        print(f"  [OK] User {uid} ({email}): {pg_score} pts -- deja synchro")
        already_ok += 1
        continue
    
    # Trouver le dernier scan pour ce user
    with engine.connect() as conn:
        last_scan = conn.execute(text(
            "SELECT waste_type, points_earned FROM bin_scans "
            "WHERE user_id = :uid ORDER BY scanned_at DESC LIMIT 1"
        ), {"uid": uid}).fetchone()
    
    waste_type = last_scan[0] if last_scan else "general"
    last_points = last_scan[1] if last_scan else pg_score
    
    # Synchroniser vers Firebase
    ok = update_user_score(uid, pg_score, last_points, waste_type, "SYNC-RECOVERY")
    if ok:
        print(f"  [SYNC] User {uid} ({email}): {pg_score} pts -> Firebase OK")
        synced += 1
        
        # Mettre a jour les scans comme synced
        with engine.connect() as conn:
            conn.execute(text(
                "UPDATE bin_scans SET firebase_synced = true WHERE user_id = :uid AND firebase_synced = false"
            ), {"uid": uid})
            conn.commit()
    else:
        print(f"  [ECHEC] User {uid} ({email}): echec sync Firebase")
        failed += 1

print(f"\n{'='*60}")
print(f"  Resultats :")
print(f"    Deja synchronises : {already_ok}")
print(f"    Nouvellement sync : {synced}")
print(f"    Echecs            : {failed}")
print(f"{'='*60}\n")
