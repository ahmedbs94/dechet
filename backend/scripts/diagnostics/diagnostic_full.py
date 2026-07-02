import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
diagnostic_full.py
==================
Script de diagnostic complet pour verifier que PostgreSQL et Firebase
fonctionnent correctement dans le projet EcoRewind.
"""
import os
import sys
import json
import time
import traceback
from datetime import datetime, timezone

# Charger .env
from dotenv import load_dotenv
load_dotenv()

PASS = "[OK]"
FAIL = "[ECHEC]"
WARN = "[WARN]"
INFO = "[INFO]"

results = []

def log(status, category, message):
    results.append((status, category, message))
    print(f"  {status} [{category}] {message}")


def sep(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


# ============================================================
# 1. POSTGRESQL
# ============================================================
def test_postgresql():
    sep("1. POSTGRESQL")

    # 1a. Connexion
    db_url = os.getenv("DATABASE_URL", "")
    if not db_url:
        log(FAIL, "PG-CONNECT", "DATABASE_URL non defini dans .env")
        return
    log(INFO, "PG-CONFIG", f"URL = ...@{db_url.split('@')[-1] if '@' in db_url else db_url}")

    try:
        from sqlalchemy import create_engine, text
        engine = create_engine(db_url, pool_pre_ping=True)
        with engine.connect() as conn:
            row = conn.execute(text("SELECT version()")).fetchone()
            log(PASS, "PG-CONNECT", f"Connexion reussie : {row[0][:60]}...")
    except Exception as e:
        log(FAIL, "PG-CONNECT", f"Impossible de se connecter : {e}")
        return

    # 1b. Lister les tables
    try:
        with engine.connect() as conn:
            rows = conn.execute(text(
                "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename"
            )).fetchall()
            tables = [r[0] for r in rows]
            log(PASS, "PG-TABLES", f"{len(tables)} tables trouvees : {', '.join(tables)}")
    except Exception as e:
        log(FAIL, "PG-TABLES", f"Erreur listage tables : {e}")
        return

    # 1c. Tables attendues
    expected_tables = [
        "users", "posts", "comments", "likes", "saved_posts",
        "otp_codes", "notifications", "collection_points",
        "testimonials", "center_proposals",
        "quizzes", "quiz_submissions",
        "video_categories", "educator_videos",
        "bin_scans"
    ]
    for t in expected_tables:
        if t in tables:
            log(PASS, "PG-TABLE", f"Table '{t}' presente")
        else:
            log(FAIL, "PG-TABLE", f"Table '{t}' MANQUANTE")

    # 1d. Compter les enregistrements dans chaque table
    print()
    print("  Comptage des enregistrements :")
    for t in expected_tables:
        if t in tables:
            try:
                with engine.connect() as conn:
                    count = conn.execute(text(f"SELECT COUNT(*) FROM {t}")).scalar()
                    log(INFO, "PG-COUNT", f"{t}: {count} enregistrements")
            except Exception as e:
                log(WARN, "PG-COUNT", f"{t}: erreur = {e}")

    # 1e. Verifier les colonnes critiques de 'users'
    try:
        with engine.connect() as conn:
            cols = conn.execute(text(
                "SELECT column_name, data_type FROM information_schema.columns "
                "WHERE table_name = 'users' ORDER BY ordinal_position"
            )).fetchall()
            col_names = [c[0] for c in cols]
            critical = ["id", "email", "full_name", "hashed_password", "role", "qr_code", "global_score"]
            for c in critical:
                if c in col_names:
                    log(PASS, "PG-SCHEMA", f"users.{c} present")
                else:
                    log(FAIL, "PG-SCHEMA", f"users.{c} MANQUANT")
    except Exception as e:
        log(FAIL, "PG-SCHEMA", f"Erreur inspection schema users : {e}")

    # 1f. Verifier les colonnes de bin_scans
    try:
        with engine.connect() as conn:
            cols = conn.execute(text(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_name = 'bin_scans' ORDER BY ordinal_position"
            )).fetchall()
            col_names = [c[0] for c in cols]
            critical = ["id", "user_id", "qr_code", "waste_type", "points_earned",
                        "score_before", "score_after", "firebase_synced"]
            for c in critical:
                if c in col_names:
                    log(PASS, "PG-SCHEMA", f"bin_scans.{c} present")
                else:
                    log(FAIL, "PG-SCHEMA", f"bin_scans.{c} MANQUANT")
    except Exception as e:
        log(WARN, "PG-SCHEMA", f"bin_scans peut ne pas exister encore : {e}")

    # 1g. Tester un INSERT/SELECT/DELETE dans une table temporaire
    try:
        with engine.connect() as conn:
            conn.execute(text("CREATE TEMP TABLE _diag_test (id serial, val text)"))
            conn.execute(text("INSERT INTO _diag_test (val) VALUES ('ecorewind_diag')"))
            r = conn.execute(text("SELECT val FROM _diag_test LIMIT 1")).scalar()
            assert r == "ecorewind_diag"
            conn.execute(text("DROP TABLE _diag_test"))
            conn.commit()
            log(PASS, "PG-CRUD", "INSERT/SELECT/DELETE operationnel")
    except Exception as e:
        log(FAIL, "PG-CRUD", f"Erreur CRUD : {e}")


# ============================================================
# 2. FIREBASE
# ============================================================
def test_firebase():
    sep("2. FIREBASE REALTIME DATABASE")

    # 2a. Credentials
    creds_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase_credentials.json")
    if not os.path.isabs(creds_path):
        creds_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), creds_path)
        creds_path = os.path.normpath(creds_path)

    if os.path.exists(creds_path):
        size = os.path.getsize(creds_path)
        log(PASS, "FB-CREDS", f"Fichier credentials trouve ({size} bytes) : {os.path.basename(creds_path)}")
        # Valider le JSON
        try:
            with open(creds_path, "r") as f:
                data = json.load(f)
            required_keys = ["type", "project_id", "private_key_id", "private_key", "client_email"]
            missing = [k for k in required_keys if k not in data]
            if missing:
                log(FAIL, "FB-CREDS", f"Cles manquantes dans credentials : {missing}")
            else:
                log(PASS, "FB-CREDS", f"Credentials valides (projet: {data.get('project_id', '?')})")
        except Exception as e:
            log(FAIL, "FB-CREDS", f"JSON invalide : {e}")
    else:
        log(FAIL, "FB-CREDS", f"Fichier introuvable : {creds_path}")
        return

    # 2b. FIREBASE_DATABASE_URL
    db_url = os.getenv("FIREBASE_DATABASE_URL", "")
    if not db_url:
        log(FAIL, "FB-URL", "FIREBASE_DATABASE_URL non defini dans .env")
        return
    log(PASS, "FB-URL", f"URL = {db_url}")

    # 2c. firebase_admin SDK
    try:
        import firebase_admin
        log(PASS, "FB-SDK", f"firebase_admin version {firebase_admin.__version__}")
    except ImportError:
        log(FAIL, "FB-SDK", "firebase_admin non installe (pip install firebase-admin)")
        return

    # 2d. Initialisation
    try:
        from firebase_admin import credentials as fb_creds
        # Nettoyer les apps existantes
        for app_name in list(firebase_admin._apps.keys()):
            firebase_admin.delete_app(firebase_admin.get_app(app_name))

        cred = fb_creds.Certificate(creds_path)
        app = firebase_admin.initialize_app(cred, {"databaseURL": db_url})
        log(PASS, "FB-INIT", f"Initialisation reussie (app: {app.name})")
    except Exception as e:
        log(FAIL, "FB-INIT", f"Echec initialisation : {e}")
        traceback.print_exc()
        return

    # 2e. Ecriture test
    try:
        from firebase_admin import db as rtdb
        test_ref = rtdb.reference("_diagnostic")
        test_data = {
            "test_time": datetime.now(timezone.utc).isoformat(),
            "source": "diagnostic_full.py",
            "status": "ok"
        }
        test_ref.set(test_data)
        log(PASS, "FB-WRITE", "Ecriture dans /_diagnostic reussie")
    except Exception as e:
        log(FAIL, "FB-WRITE", f"Echec ecriture : {e}")
        traceback.print_exc()
        return

    # 2f. Lecture test
    try:
        read_data = test_ref.get()
        if read_data and read_data.get("status") == "ok":
            log(PASS, "FB-READ", f"Lecture /_diagnostic reussie : {read_data}")
        else:
            log(FAIL, "FB-READ", f"Donnees lues incorrectes : {read_data}")
    except Exception as e:
        log(FAIL, "FB-READ", f"Echec lecture : {e}")

    # 2g. Nettoyage
    try:
        test_ref.delete()
        log(PASS, "FB-DELETE", "Nettoyage /_diagnostic reussi")
    except Exception as e:
        log(WARN, "FB-DELETE", f"Echec nettoyage : {e}")

    # 2h. Lire les scores existants
    try:
        scores_ref = rtdb.reference("scores")
        scores = scores_ref.get()
        if scores:
            log(PASS, "FB-SCORES", f"{len(scores)} utilisateur(s) avec score Firebase :")
            for uid, data in scores.items():
                total = data.get("total", "?")
                last = data.get("last_scan", "?")
                log(INFO, "FB-SCORES", f"  User {uid}: {total} pts (dernier scan: {last})")
        else:
            log(INFO, "FB-SCORES", "Aucun score dans Firebase (normal si aucun scan QR effectue)")
    except Exception as e:
        log(WARN, "FB-SCORES", f"Erreur lecture scores : {e}")


# ============================================================
# 3. INTEGRATION : QR Scan flow
# ============================================================
def test_integration():
    sep("3. INTEGRATION : Flux QR Scan")

    import urllib.request
    import json

    base = "http://127.0.0.1:8000"

    # 3a. Backend en ligne ?
    try:
        r = urllib.request.urlopen(f"{base}/")
        data = json.loads(r.read().decode())
        log(PASS, "API-HEALTH", f"Backend OK : {data}")
    except Exception as e:
        log(FAIL, "API-HEALTH", f"Backend injoignable : {e}")
        return

    # 3b. Lister les endpoints principaux
    endpoints_to_check = [
        ("GET", "/users/me", None, "Auth requis - devrait retourner 401"),
        ("GET", "/collection-points/", None, "Points de collecte"),
        ("GET", "/posts/", None, "Liste des posts"),
        ("GET", "/educator-videos/", None, "Videos educatives"),
        ("GET", "/testimonials/", None, "Temoignages"),
        ("GET", "/stats", None, "Statistiques communaute"),
    ]

    for method, path, body, desc in endpoints_to_check:
        try:
            url = f"{base}{path}"
            req = urllib.request.Request(url, method=method)
            if body:
                req.add_header("Content-Type", "application/json")
                req.data = json.dumps(body).encode()
            try:
                r = urllib.request.urlopen(req)
                status = r.status
            except urllib.error.HTTPError as he:
                status = he.code
            if status in (200, 401, 403):
                log(PASS, "API-ENDPOINT", f"{method} {path} -> {status} ({desc})")
            else:
                log(WARN, "API-ENDPOINT", f"{method} {path} -> {status} ({desc})")
        except Exception as e:
            log(FAIL, "API-ENDPOINT", f"{method} {path} -> ERREUR : {e}")

    # 3c. Test login + scan QR
    print()
    print("  Test flux complet : Login -> Scan QR -> Score")

    # Trouver un user pour le test
    try:
        from sqlalchemy import create_engine, text
        db_url = os.getenv("DATABASE_URL", "")
        engine = create_engine(db_url, pool_pre_ping=True)
        with engine.connect() as conn:
            user = conn.execute(text(
                "SELECT id, email, qr_code, global_score FROM users WHERE role = 'user' LIMIT 1"
            )).fetchone()
            if user:
                log(INFO, "TEST-USER", f"User test: id={user[0]}, email={user[1]}, score={user[3]}")
                log(INFO, "TEST-USER", f"QR code: {user[2][:40]}...")
            else:
                log(WARN, "TEST-USER", "Aucun utilisateur 'user' trouve pour le test de scan")
    except Exception as e:
        log(WARN, "TEST-USER", f"Erreur recherche user test : {e}")

    # 3d. Verifier les derniers scans QR dans PostgreSQL
    try:
        with engine.connect() as conn:
            scans = conn.execute(text(
                "SELECT id, user_id, waste_type, points_earned, score_after, firebase_synced, scanned_at "
                "FROM bin_scans ORDER BY scanned_at DESC LIMIT 5"
            )).fetchall()
            if scans:
                log(PASS, "PG-SCANS", f"{len(scans)} dernier(s) scan(s) QR dans PostgreSQL :")
                for s in scans:
                    synced = "Firebase OK" if s[5] else "Firebase NON synced"
                    log(INFO, "PG-SCANS", f"  Scan #{s[0]}: user={s[1]}, type={s[2]}, pts={s[3]}, score_after={s[4]}, {synced}, {s[6]}")
            else:
                log(INFO, "PG-SCANS", "Aucun scan QR enregistre dans bin_scans")
    except Exception as e:
        log(WARN, "PG-SCANS", f"Table bin_scans peut ne pas exister : {e}")

    # 3e. Comparer score PG vs Firebase
    try:
        from services.firebase_service import get_user_score
        with engine.connect() as conn:
            users_with_score = conn.execute(text(
                "SELECT id, email, global_score FROM users WHERE global_score > 0 ORDER BY global_score DESC LIMIT 5"
            )).fetchall()

        if users_with_score:
            print()
            print("  Comparaison scores PostgreSQL vs Firebase :")
            for u in users_with_score:
                uid, email, pg_score = u[0], u[1], u[2]
                fb_data = get_user_score(uid)
                fb_score = fb_data.get("total", "N/A") if fb_data else "N/A"
                match = "MATCH" if fb_data and abs(float(fb_score) - float(pg_score)) < 0.01 else "MISMATCH"
                status = PASS if match == "MATCH" else WARN
                log(status, "SYNC-CHECK", f"User {uid} ({email}): PG={pg_score} | Firebase={fb_score} [{match}]")
        else:
            log(INFO, "SYNC-CHECK", "Aucun utilisateur avec score > 0")
    except Exception as e:
        log(WARN, "SYNC-CHECK", f"Erreur comparaison : {e}")


# ============================================================
# RAPPORT FINAL
# ============================================================
def print_report():
    sep("RAPPORT FINAL")

    total = len(results)
    passed = sum(1 for r in results if r[0] == PASS)
    failed = sum(1 for r in results if r[0] == FAIL)
    warned = sum(1 for r in results if r[0] == WARN)
    info = sum(1 for r in results if r[0] == INFO)

    print(f"""
  Total tests : {total}
  {PASS} Reussis  : {passed}
  {FAIL} Echoues  : {failed}
  {WARN} Warnings : {warned}
  {INFO} Info     : {info}
""")

    if failed > 0:
        print(f"  ECHECS DETECTES :")
        for r in results:
            if r[0] == FAIL:
                print(f"    {FAIL} [{r[1]}] {r[2]}")
        print()
    
    if failed == 0:
        print("  >>> TOUT FONCTIONNE CORRECTEMENT ! <<<")
    else:
        print(f"  >>> {failed} PROBLEME(S) DETECTE(S) -- voir ci-dessus <<<")

    print(f"\n{'='*60}\n")


# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    print(f"\n{'='*60}")
    print(f"  DIAGNOSTIC COMPLET ECOREWIND")
    print(f"  Date : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*60}")

    test_postgresql()
    test_firebase()
    test_integration()
    print_report()
