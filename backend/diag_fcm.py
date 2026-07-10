import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'))

print("=" * 55)
print("  DIAGNOSTIC FCM / PUSH NOTIFICATIONS")
print("=" * 55)

# --- Test 1 : Credentials Firebase ---
creds = os.getenv('FIREBASE_CREDENTIALS_PATH', 'firebase_credentials.json')
if not os.path.isabs(creds):
    creds = os.path.join(os.path.dirname(os.path.abspath(__file__)), creds)
exists = os.path.exists(creds)
print(f"[1] Credentials path : {creds}")
print(f"    Existe           : {exists}")
if exists:
    try:
        import json
        with open(creds) as f:
            data = json.load(f)
        print(f"    project_id       : {data.get('project_id','?')}")
        print(f"    client_email     : {data.get('client_email','?')[:40]}...")
    except Exception as e:
        print(f"    [ERR lecture] {e}")

# --- Test 2 : URL RTDB ---
db_url = os.getenv('FIREBASE_DATABASE_URL', '')
print(f"[2] FIREBASE_DATABASE_URL : {db_url if db_url else '(non defini)'}")

# --- Test 3 : Init FCM Admin SDK ---
try:
    from services.fcm_push_service import _init_fcm
    ok = _init_fcm()
    print(f"[3] _init_fcm() -> {ok}")
except Exception as e:
    print(f"[3] _init_fcm() ERREUR : {e}")

# --- Test 4 : Users avec token FCM ---
try:
    import app.users.models, app.qr_bins.models
    import app.collection_points.models, app.posts.models
    from database import SessionLocal
    from app.users.models import User
    db = SessionLocal()
    total = db.query(User).count()
    with_token = db.query(User).filter(User.fcm_token != None, User.fcm_token != '').all()
    print(f"[4] Total users : {total}")
    print(f"    Avec token FCM : {len(with_token)}")
    for u in with_token[:5]:
        tok = (u.fcm_token or '')[:35]
        print(f"    - {u.full_name} ({u.role}) : {tok}...")
    db.close()
except Exception as e:
    print(f"[4] ERREUR lecture users : {e}")

# --- Test 5 : Envoi push test ---
print()
print("[5] Test envoi push (si token disponible)...")
try:
    from services.fcm_push_service import _init_fcm, send_push_to_user
    import app.users.models, app.qr_bins.models
    import app.collection_points.models, app.posts.models
    from database import SessionLocal
    from app.users.models import User
    if _init_fcm():
        db = SessionLocal()
        target = db.query(User).filter(
            User.fcm_token != None, User.fcm_token != ''
        ).first()
        if target:
            print(f"    -> Envoi test a : {target.full_name} (id={target.id})")
            result = send_push_to_user(
                db, target.id,
                title="[TEST] EcoRewind",
                body="Notification test - si vous voyez ceci FCM fonctionne",
                data={"type": "info"},
            )
            print(f"    -> Resultat : {result}")
        else:
            print("    -> Aucun user avec token FCM disponible pour tester")
        db.close()
    else:
        print("    -> Firebase non disponible, test ignore")
except Exception as e:
    print(f"    -> ERREUR test : {e}")
    import traceback
    traceback.print_exc()

print("=" * 55)
