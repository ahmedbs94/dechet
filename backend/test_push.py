"""
Test push notification direct vers l'utilisateur connecte.
Doit etre lance AVEC le backend en cours (uvicorn).
"""
import sys, os, requests, json
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, '.')

BASE = "http://127.0.0.1:8000"

# 1. Verifier si le backend repond
try:
    r = requests.get(f"{BASE}/health", timeout=3)
    print(f"Backend repond: {r.status_code}")
except Exception as e:
    print(f"BACKEND PAS ACCESSIBLE: {e}")
    sys.exit(1)

# 2. Lire les users avec fcm_token depuis la BDD
from database import engine
from sqlalchemy import text
with engine.connect() as conn:
    r2 = conn.execute(text("SELECT id, full_name, role, fcm_token FROM users WHERE fcm_token IS NOT NULL AND fcm_token != '' LIMIT 5"))
    users = r2.fetchall()
    print(f"\nUsers avec FCM token: {len(users)}")
    for u in users:
        print(f"  id={u[0]} name={u[1]} role={u[2]} token={u[3][:20]}...")

if not users:
    print("\nAUCUN FCM TOKEN — l'utilisateur doit se connecter avec le nouvel APK d'abord!")
    # Verifier les tokens FCM recus depuis le boot
    from services.fcm_push_service import _init_fcm
    _init_fcm()
    print("\nTest FCM Admin SDK OK — le probleme est le token manquant")
    sys.exit(0)

# 3. Envoyer un push test
from services.fcm_push_service import send_push_to_user
from database import SessionLocal
db = SessionLocal()
try:
    for u in users:
        ok = send_push_to_user(
            db, u[0],
            title="🔔 Test Push EcoRewind",
            body=f"Bonjour {u[1]} ! Les notifications push fonctionnent correctement.",
            data={"type": "info"}
        )
        print(f"Push envoyé à {u[1]}: {'✅ OK' if ok else '❌ ECHEC'}")
finally:
    db.close()
