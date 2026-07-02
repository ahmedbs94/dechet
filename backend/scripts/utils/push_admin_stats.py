import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
push_admin_stats.py
====================
Script de déclenchement manuel — pousse /admin_stats/ dans Firebase RTDB
immédiatement depuis la base de données locale.

Exécution :
    cd backend
    python push_admin_stats.py
"""

import os
import sys
import traceback

# Fix encodage Windows
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

# Charger .env
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(BASE_DIR, ".env"))
    print("[ENV] Variables .env chargees")
except ImportError:
    print("[ENV] python-dotenv absent — variables systeme utilisees")

# Verifier les variables Firebase
db_url = os.getenv("FIREBASE_DATABASE_URL", "")
creds  = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase_credentials.json")
print(f"[ENV] FIREBASE_DATABASE_URL = {db_url or '(vide!)'}")
print(f"[ENV] FIREBASE_CREDENTIALS_PATH = {creds}")

creds_abs = creds if os.path.isabs(creds) else os.path.normpath(os.path.join(BASE_DIR, creds))
print(f"[ENV] Chemin credentials resolu = {creds_abs}")
print(f"[ENV] Credentials existe = {os.path.exists(creds_abs)}")

if not db_url:
    print("[ERREUR] FIREBASE_DATABASE_URL est vide dans .env — impossible de continuer")
    sys.exit(1)
if not os.path.exists(creds_abs):
    print("[ERREUR] firebase_credentials.json introuvable — impossible de continuer")
    sys.exit(1)

# Initialiser Firebase directement pour test
print("\n[Firebase] Initialisation...")
try:
    import firebase_admin
    from firebase_admin import credentials, db as rtdb

    if not firebase_admin._apps:
        cred = credentials.Certificate(creds_abs)
        firebase_admin.initialize_app(cred, {"databaseURL": db_url})
        print(f"[Firebase] Connecte a : {db_url}")
    else:
        print("[Firebase] Deja initialise")
except Exception as e:
    print(f"[Firebase] ERREUR initialisation : {e}")
    traceback.print_exc()
    sys.exit(1)

# Importer les modeles et la base de donnees
print("\n[DB] Connexion base de donnees...")
try:
    # Charger tous les modeles pour resoudre les relations SQLAlchemy
    import app.users.models
    import app.qr_bins.models
    import app.collection_points.models
    import app.community.models
    import app.posts.models
    import app.quiz.models
    import app.education.models
    import app.notifications.models
    import app.auth.models

    from database import SessionLocal
    from sqlalchemy import func
    from datetime import datetime, timedelta, timezone

    db = SessionLocal()
    print("[DB] OK")
except Exception as e:
    print(f"[DB] ERREUR : {e}")
    traceback.print_exc()
    sys.exit(1)

# Calculer les statistiques
print("\n[STATS] Calcul des statistiques...")
now = datetime.now(timezone.utc).replace(tzinfo=None)
since_week  = now - timedelta(days=7)
since_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
since_month = now - timedelta(days=30)

from app.users.models import User
from app.qr_bins.models import BinScan

# --- Utilisateurs ---
total_users = db.query(func.count(User.id)).scalar() or 0
print(f"  total_users = {total_users}")

# Tenter avec created_at (nom le plus courant)
try:
    new_users_month = db.query(func.count(User.id)).filter(User.created_at >= since_month).scalar() or 0
    # Utilisateurs ayant scanné cette semaine (pas ceux créés cette semaine)
    active_users_week = db.query(
        func.count(func.distinct(BinScan.user_id))
    ).filter(BinScan.scanned_at >= since_week).scalar() or 0
    print(f"  new_users_month        = {new_users_month}")
    print(f"  active_users_week (ont scanné 7j) = {active_users_week}")
except Exception as e:
    print(f"  [WARN] erreur calcul actifs/nouveaux : {e}")
    new_users_month = 0
    active_users_week = 0

avg_score = float(db.query(func.avg(User.global_score)).scalar() or 0.0)
print(f"  average_score = {avg_score:.2f}")

# --- Scans ---
total_scans = db.query(func.count(BinScan.id)).scalar() or 0
print(f"  total_scans = {total_scans}")

try:
    scans_today = db.query(func.count(BinScan.id)).filter(BinScan.scanned_at >= since_today).scalar() or 0
    scans_week  = db.query(func.count(BinScan.id)).filter(BinScan.scanned_at >= since_week).scalar() or 0
    print(f"  scans_today (scanned_at) = {scans_today}")
    print(f"  scans_week  (scanned_at) = {scans_week}")
except Exception as e:
    print(f"  [WARN] scanned_at non disponible : {e}")
    # Essayer created_at pour BinScan
    try:
        scans_today = db.query(func.count(BinScan.id)).filter(BinScan.created_at >= since_today).scalar() or 0
        scans_week  = db.query(func.count(BinScan.id)).filter(BinScan.created_at >= since_week).scalar() or 0
        print(f"  scans_today (created_at fallback) = {scans_today}")
        print(f"  scans_week  (created_at fallback) = {scans_week}")
    except Exception as e2:
        print(f"  [WARN] created_at aussi absent : {e2}")
        scans_today = 0
        scans_week  = 0

points_total = float(db.query(func.sum(BinScan.points_earned)).scalar() or 0.0)
print(f"  points_distributed = {points_total:.2f}")

# --- Collectes (CollectorLog) ---
try:
    from app.qr_bins.models import CollectorLog
    total_collections = db.query(func.count(CollectorLog.id)).scalar() or 0
    collections_week  = db.query(func.count(CollectorLog.id)).filter(
        CollectorLog.collected_at >= since_week
    ).scalar() or 0
    print(f"  total_collections = {total_collections}")
    print(f"  collections_week  = {collections_week}")
except Exception as e:
    print(f"  [WARN] CollectorLog non disponible : {e}")
    total_collections = 0
    collections_week  = 0

# --- Centres ---
try:
    from app.collection_points.models import CollectionPoint
    total_centers  = db.query(func.count(CollectionPoint.id)).scalar() or 0
    active_centers = db.query(func.count(CollectionPoint.id)).filter(
        CollectionPoint.status == 'disponible'
    ).scalar() or 0
    print(f"  total_centers  = {total_centers}")
    print(f"  active_centers = {active_centers}")
except Exception as e:
    print(f"  [WARN] CollectionPoint non disponible : {e}")
    total_centers  = 0
    active_centers = 0

# --- Moderation ---
try:
    from app.posts.models import Post
    pending_mod = db.query(func.count(Post.id)).filter(
        Post.status.in_(['pending_ai', 'pending_review'])
    ).scalar() or 0
    print(f"  pending_moderation = {pending_mod}")
except Exception as e:
    print(f"  [WARN] Post non disponible : {e}")
    pending_mod = 0

try:
    from app.community.models import CenterProposal
    pending_proposals = db.query(func.count(CenterProposal.id)).filter(
        CenterProposal.status == 'pending'
    ).scalar() or 0
    print(f"  pending_proposals = {pending_proposals}")
except Exception as e:
    print(f"  [WARN] CenterProposal non disponible : {e}")
    pending_proposals = 0

try:
    from app.community.models import Testimonial
    pending_testimonials = db.query(func.count(Testimonial.id)).filter(
        Testimonial.is_approved == False  # noqa: E712
    ).scalar() or 0
    print(f"  pending_testimonials = {pending_testimonials}")
except Exception as e:
    print(f"  [WARN] Testimonial non disponible : {e}")
    pending_testimonials = 0

db.close()

# Construire le payload
stats = {
    "total_users":          int(total_users),
    "active_users_week":    int(active_users_week),
    "new_users_month":      int(new_users_month),
    "average_score":        round(avg_score, 2),
    "total_scans":          int(total_scans),
    "scans_today":          int(scans_today),
    "scans_week":           int(scans_week),
    "points_distributed":   round(points_total, 2),
    "total_collections":    int(total_collections),
    "collections_week":     int(collections_week),
    "pending_moderation":   int(pending_mod),
    "pending_testimonials": int(pending_testimonials),
    "pending_proposals":    int(pending_proposals),
    "total_centers":        int(total_centers),
    "active_centers":       int(active_centers),
    "last_updated":         datetime.now(timezone.utc).isoformat(),
}

print(f"\n[PUSH] Payload pret : {stats}")

# Ecrire dans Firebase RTDB
print("\n[Firebase] Ecriture /admin_stats/ ...")
try:
    ref = rtdb.reference("admin_stats")
    ref.set(stats)
    print("[Firebase] [OK] /admin_stats/ ecrit avec succes !")
    print(f"[Firebase] URL : {db_url}/admin_stats.json")
except Exception as e:
    print(f"[Firebase] [ERREUR] : {e}")
    traceback.print_exc()
    sys.exit(1)

print("\n[DONE] Termine. Verifiez la Firebase Console.")
