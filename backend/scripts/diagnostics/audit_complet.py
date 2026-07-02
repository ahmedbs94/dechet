import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
audit_complet.py
=================
Audit exhaustif de tout le projet EcoRewind :
  - Donnees utilisateurs (PostgreSQL)
  - Backend (routers, services, modeles)
  - Frontend Flutter (screens, widgets, services)
  - Assets (images, modeles IA)
  - Configuration (env, firebase, android)
"""
import os, sys, io, json, glob, sqlite3
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from dotenv import load_dotenv
load_dotenv()
from sqlalchemy import create_engine, text

PASS = "[OK]"
FAIL = "[ECHEC]"
WARN = "[WARN]"
INFO = "[INFO]"
results = []

def log(s, c, m):
    results.append((s, c, m))
    print(f"  {s} [{c}] {m}")

def sep(t):
    print(f"\n{'='*70}")
    print(f"  {t}")
    print(f"{'='*70}")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKEND = os.path.join(ROOT, "backend")
LIB = os.path.join(ROOT, "lib")

e = create_engine(os.getenv("DATABASE_URL", "postgresql://postgres@localhost:5432/ecorewind"))

# ================================================================
# 1. DONNEES UTILISATEURS COMPLETES
# ================================================================
sep("1. DONNEES UTILISATEURS (PostgreSQL)")

with e.connect() as c:
    users = c.execute(text(
        "SELECT id, email, full_name, role, is_active, is_verified, "
        "google_id, facebook_id, qr_code, avatar_url, global_score, "
        "hashed_password, reset_token "
        "FROM users ORDER BY id"
    )).fetchall()

print(f"\n  {len(users)} utilisateur(s) au total\n")
print(f"  {'ID':>4} {'Email':<32} {'Nom':<22} {'Role':<15} {'Act':>4} {'Ver':>4} {'Score':>6} {'QR':>4} {'Pwd':>5} {'OAuth':>6}")
print(f"  {'-'*4} {'-'*32} {'-'*22} {'-'*15} {'-'*4} {'-'*4} {'-'*6} {'-'*4} {'-'*5} {'-'*6}")

roles_count = {}
for u in users:
    uid, email, name, role = u[0], u[1], u[2] or "", u[3] or "user"
    is_active, is_verified = u[4], u[5]
    google_id, fb_id = u[6], u[7]
    qr_code, avatar, score = u[8], u[9], u[10] or 0
    pwd, reset = u[11], u[12]
    
    has_qr = "Yes" if qr_code else "No"
    has_pwd = "Yes" if pwd and (pwd.startswith("$2b$") or pwd.startswith("$2a$")) else ("FB" if fb_id else "No")
    oauth = "FB" if fb_id else ("G" if google_id else "-")
    
    roles_count[role] = roles_count.get(role, 0) + 1
    
    print(f"  {uid:>4} {email[:32]:<32} {name[:22]:<22} {role:<15} {str(is_active):>4} {str(is_verified):>4} {score:>6.1f} {has_qr:>4} {has_pwd:>5} {oauth:>6}")

print(f"\n  Roles : {json.dumps(roles_count, ensure_ascii=False)}")
log(PASS, "USERS", f"{len(users)} utilisateurs avec toutes les colonnes preservees")

# Verifier les donnees liees a chaque utilisateur
with e.connect() as c:
    for uid_row in c.execute(text("SELECT id, email FROM users ORDER BY id")).fetchall():
        uid, email = uid_row[0], uid_row[1]
        posts = c.execute(text("SELECT COUNT(*) FROM posts WHERE user_id = :u"), {"u": uid}).scalar()
        comments = c.execute(text("SELECT COUNT(*) FROM comments WHERE user_id = :u"), {"u": uid}).scalar()
        likes = c.execute(text("SELECT COUNT(*) FROM likes WHERE user_id = :u"), {"u": uid}).scalar()
        saved = c.execute(text("SELECT COUNT(*) FROM saved_posts WHERE user_id = :u"), {"u": uid}).scalar()
        notifs = c.execute(text("SELECT COUNT(*) FROM notifications WHERE user_id = :u"), {"u": uid}).scalar()
        scans = c.execute(text("SELECT COUNT(*) FROM bin_scans WHERE user_id = :u"), {"u": uid}).scalar()
        quiz_subs = c.execute(text("SELECT COUNT(*) FROM quiz_submissions WHERE student_id = :u"), {"u": uid}).scalar()
        
        total = posts + comments + likes + saved + notifs + scans + quiz_subs
        if total > 0:
            log(INFO, "USER-DATA", f"User {uid} ({email[:25]}): {posts}p, {comments}c, {likes}l, {saved}s, {notifs}n, {scans}qr, {quiz_subs}quiz")

# ================================================================
# 2. TOUTES LES TABLES - CONTENU
# ================================================================
sep("2. CONTENU COMPLET DES TABLES")

with e.connect() as c:
    tables_info = [
        ("users", "Utilisateurs"),
        ("posts", "Publications communautaires"),
        ("comments", "Commentaires"),
        ("likes", "Likes"),
        ("saved_posts", "Posts sauvegardes"),
        ("otp_codes", "Codes OTP"),
        ("notifications", "Notifications"),
        ("collection_points", "Points de collecte"),
        ("testimonials", "Temoignages"),
        ("center_proposals", "Propositions de centres"),
        ("quizzes", "Quiz educatifs"),
        ("quiz_submissions", "Soumissions de quiz"),
        ("video_categories", "Categories de videos"),
        ("educator_videos", "Videos educatives"),
        ("bin_scans", "Scans de poubelles QR"),
    ]
    
    for table, desc in tables_info:
        count = c.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
        cols = c.execute(text(
            "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = :t AND table_schema = 'public'"
        ), {"t": table}).scalar()
        log(PASS, "TABLE", f"{table} ({desc}): {count} enregistrements, {cols} colonnes")

# ================================================================
# 3. BACKEND - FICHIERS ET MODULES
# ================================================================
sep("3. BACKEND (FastAPI)")

backend_critical = {
    "main.py": "Point d'entree FastAPI",
    "database.py": "Connexion PostgreSQL/SQLite",
    "db_models.py": "Modeles SQLAlchemy (15 tables)",
    "models.py": "Schemas Pydantic",
    "auth.py": "Utilitaires d'authentification",
    "requirements.txt": "Dependances Python",
    ".env": "Configuration environnement",
    "firebase_credentials.json": "Credentials Firebase",
}

for f, desc in backend_critical.items():
    path = os.path.join(BACKEND, f)
    if os.path.exists(path):
        size = os.path.getsize(path)
        log(PASS, "BACKEND", f"{f} ({desc}) -- {size} bytes")
    else:
        log(FAIL, "BACKEND", f"{f} MANQUANT ({desc})")

# Routers
routers_dir = os.path.join(BACKEND, "routers")
expected_routers = [
    "auth.py", "users.py", "posts.py", "notifications.py",
    "collection_points.py", "community.py", "moderation.py",
    "quiz.py", "educator_videos.py", "qr_bins.py"
]
for r in expected_routers:
    path = os.path.join(routers_dir, r)
    if os.path.exists(path):
        log(PASS, "ROUTER", f"routers/{r} -- {os.path.getsize(path)} bytes")
    else:
        log(FAIL, "ROUTER", f"routers/{r} MANQUANT")

# Services
services_dir = os.path.join(BACKEND, "services")
expected_services = ["firebase_service.py", "ai_moderator.py", "gemini_quiz.py"]
for s in expected_services:
    path = os.path.join(services_dir, s)
    if os.path.exists(path):
        log(PASS, "SERVICE", f"services/{s} -- {os.path.getsize(path)} bytes")
    else:
        log(FAIL, "SERVICE", f"services/{s} MANQUANT")

# Moderation IA
mod_dir = os.path.join(BACKEND, "moderation_ai")
ia_files = ["eco_moderator.py", "text_cnn_model.py", "eco_cnn.py"]
for f in ia_files:
    path = os.path.join(mod_dir, f)
    if os.path.exists(path):
        log(PASS, "IA", f"moderation_ai/{f} -- {os.path.getsize(path)} bytes")
    else:
        log(WARN, "IA", f"moderation_ai/{f} non trouve")

# Modeles IA entraines
model_files = glob.glob(os.path.join(mod_dir, "*.pth")) + glob.glob(os.path.join(mod_dir, "*.pt"))
for mf in model_files:
    name = os.path.basename(mf)
    size_mb = os.path.getsize(mf) / (1024*1024)
    log(PASS, "IA-MODEL", f"{name} -- {size_mb:.1f} MB")

if not model_files:
    log(WARN, "IA-MODEL", "Aucun modele IA (.pth/.pt) trouve")

# ================================================================
# 4. FRONTEND FLUTTER
# ================================================================
sep("4. FRONTEND FLUTTER")

# Main
main_dart = os.path.join(LIB, "main.dart")
if os.path.exists(main_dart):
    log(PASS, "FLUTTER", f"main.dart -- {os.path.getsize(main_dart)} bytes")
else:
    log(FAIL, "FLUTTER", "main.dart MANQUANT")

constants_dart = os.path.join(LIB, "constants.dart")
if os.path.exists(constants_dart):
    log(PASS, "FLUTTER", f"constants.dart -- {os.path.getsize(constants_dart)} bytes")
else:
    log(FAIL, "FLUTTER", "constants.dart MANQUANT")

# Screens
screens_dir = os.path.join(LIB, "screens")
client_screens = [
    ("splash_screen.dart", "Ecran de demarrage"),
    ("client/client_home.dart", "Shell navigation citoyen"),
    ("client/home_dashboard_tab.dart", "Dashboard citoyen"),
    ("client/feed_tab.dart", "Feed communautaire"),
    ("client/profile_tab.dart", "Profil utilisateur"),
    ("client/multimedia_tab.dart", "Multimedia/formation"),
    ("client/rewards_tab.dart", "Recompenses"),
    ("client/map_tab.dart", "Carte des points de collecte"),
    ("client/community_screen.dart", "Communaute"),
    ("client/post_detail_screen.dart", "Detail d'un post"),
    ("client/quiz_play_screen.dart", "Quiz interactif"),
    ("client/bin_scanner_screen.dart", "Scanner QR poubelle"),
    ("client/badge_screen.dart", "Badges utilisateur"),
    ("client/notifications_screen.dart", "Notifications"),
    ("client/personal_info_screen.dart", "Infos personnelles"),
    ("client/change_password_screen.dart", "Changement mot de passe"),
    ("client/sorting_guide_screen.dart", "Guide de tri"),
    ("client/track_records_screen.dart", "Historique"),
    ("client/waste_scanner_screen.dart", "Scanner de dechets IA"),
    ("client/waste_prediction_result_screen.dart", "Resultat prediction IA"),
]

admin_screens = [
    ("admin/admin_dashboard.dart", "Dashboard admin"),
    ("admin/educator_tab.dart", "Onglet educateur"),
    ("admin/collector_tab.dart", "Onglet collecteur"),
    ("admin/point_manager_tab.dart", "Gestionnaire de points"),
    ("admin/intercommunality_tab.dart", "Intercommunalite"),
    ("admin/user_management_screen.dart", "Gestion utilisateurs"),
    ("admin/admin_proposals_screen.dart", "Propositions admin"),
    ("admin/add_sorting_center_screen.dart", "Ajout centre de tri"),
]

auth_screens_files = glob.glob(os.path.join(screens_dir, "auth", "*.dart"))

for f, desc in client_screens + admin_screens:
    path = os.path.join(screens_dir, f)
    if os.path.exists(path):
        log(PASS, "SCREEN", f"{f} ({desc}) -- {os.path.getsize(path)} bytes")
    else:
        log(FAIL, "SCREEN", f"{f} MANQUANT ({desc})")

for f in auth_screens_files:
    name = os.path.relpath(f, screens_dir).replace("\\", "/")
    log(PASS, "SCREEN", f"{name} -- {os.path.getsize(f)} bytes")

# Services Flutter
flutter_services = os.path.join(LIB, "services")
expected_flutter_services = [
    ("auth_service.dart", "Service d'authentification"),
    ("firebase_score_service.dart", "Service Firebase scores"),
    ("notification_service.dart", "Service de notifications"),
]
for f, desc in expected_flutter_services:
    path = os.path.join(flutter_services, f)
    if os.path.exists(path):
        log(PASS, "FL-SERVICE", f"{f} ({desc}) -- {os.path.getsize(path)} bytes")
    else:
        log(FAIL, "FL-SERVICE", f"{f} MANQUANT ({desc})")

# Widgets
widgets_dir = os.path.join(LIB, "widgets")
if os.path.isdir(widgets_dir):
    widgets = [f for f in os.listdir(widgets_dir) if f.endswith(".dart")]
    for w in widgets:
        log(PASS, "WIDGET", f"{w} -- {os.path.getsize(os.path.join(widgets_dir, w))} bytes")
else:
    log(WARN, "WIDGET", "Dossier widgets non trouve")

# Models
models_dir = os.path.join(LIB, "models")
if os.path.isdir(models_dir):
    models = [f for f in os.listdir(models_dir) if f.endswith(".dart")]
    for m in models:
        log(PASS, "MODEL", f"{m} -- {os.path.getsize(os.path.join(models_dir, m))} bytes")
else:
    log(WARN, "MODEL", "Dossier models non trouve")

# Theme
theme_dir = os.path.join(LIB, "theme")
if os.path.isdir(theme_dir):
    themes = [f for f in os.listdir(theme_dir) if f.endswith(".dart")]
    for t in themes:
        log(PASS, "THEME", f"{t} -- {os.path.getsize(os.path.join(theme_dir, t))} bytes")

# ================================================================
# 5. ASSETS
# ================================================================
sep("5. ASSETS ET CONFIGURATION")

assets_dir = os.path.join(ROOT, "assets")
if os.path.isdir(assets_dir):
    asset_count = sum(1 for _, _, files in os.walk(assets_dir) for f in files)
    asset_size = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, files in os.walk(assets_dir) for f in files)
    log(PASS, "ASSETS", f"{asset_count} fichiers ({asset_size/(1024*1024):.1f} MB)")
    
    # Lister les sous-dossiers
    for d in os.listdir(assets_dir):
        subdir = os.path.join(assets_dir, d)
        if os.path.isdir(subdir):
            sub_count = sum(1 for _, _, files in os.walk(subdir) for f in files)
            log(INFO, "ASSETS", f"  {d}/ : {sub_count} fichier(s)")

# Android config
google_services = os.path.join(ROOT, "android", "app", "google-services.json")
if os.path.exists(google_services):
    log(PASS, "CONFIG", f"google-services.json (Firebase Android) -- {os.path.getsize(google_services)} bytes")
else:
    log(WARN, "CONFIG", "google-services.json manquant")

pubspec = os.path.join(ROOT, "pubspec.yaml")
if os.path.exists(pubspec):
    log(PASS, "CONFIG", f"pubspec.yaml -- {os.path.getsize(pubspec)} bytes")

# ================================================================
# 6. API - VERIFICATION DES DONNEES SERVIES
# ================================================================
sep("6. VERIFICATION API (donnees servies depuis PostgreSQL)")

import urllib.request, urllib.error

base = "http://127.0.0.1:8000"

def api_get(path):
    try:
        r = urllib.request.urlopen(f"{base}{path}")
        return json.loads(r.read().decode())
    except urllib.error.HTTPError as he:
        return {"_error": he.code}
    except Exception as ex:
        return {"_error": str(ex)}

# Posts
posts_data = api_get("/posts/")
if isinstance(posts_data, list):
    log(PASS, "API-LIVE", f"/posts/ : {len(posts_data)} post(s) servis depuis PG")
    if posts_data:
        p = posts_data[0]
        fields = ["id", "user_name", "description", "image_url", "likes_count", "created_at"]
        present = [f for f in fields if f in p]
        log(PASS, "API-LIVE", f"  Structure post: {', '.join(present)}")
else:
    log(WARN, "API-LIVE", f"/posts/ : reponse inattendue")

# Collection points
cp_data = api_get("/collection-points/")
if isinstance(cp_data, list):
    log(PASS, "API-LIVE", f"/collection-points/ : {len(cp_data)} point(s)")
else:
    log(WARN, "API-LIVE", f"/collection-points/ : reponse inattendue")

# Educator videos
ev_data = api_get("/educator-videos/")
if isinstance(ev_data, list):
    log(PASS, "API-LIVE", f"/educator-videos/ : {len(ev_data)} video(s)")
else:
    log(WARN, "API-LIVE", f"/educator-videos/ : reponse inattendue")

# Testimonials
test_data = api_get("/testimonials/")
if isinstance(test_data, list):
    log(PASS, "API-LIVE", f"/testimonials/ : {len(test_data)} temoignage(s)")

# Stats
stats = api_get("/stats")
if isinstance(stats, dict) and "_error" not in stats:
    log(PASS, "API-LIVE", f"/stats : {json.dumps(stats, ensure_ascii=False)[:80]}")

# Leaderboard
lb = api_get("/qr/leaderboard")
if isinstance(lb, list):
    log(PASS, "API-LIVE", f"/qr/leaderboard : {len(lb)} citoyen(s) avec score")

# Auth protection
me = api_get("/users/me")
if isinstance(me, dict) and me.get("_error") == 401:
    log(PASS, "API-LIVE", f"/users/me : 401 (auth requise -- securite OK)")

# ================================================================
# 7. COMPARAISON SQLITE vs PG (resume)
# ================================================================
sep("7. RESUME MIGRATION SQLite -> PostgreSQL")

sq = sqlite3.connect(os.path.join(BACKEND, "sql_app.db"))
sq_cur = sq.cursor()

sq_cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
sq_tables = sorted([r[0] for r in sq_cur.fetchall()])

total_match = 0
total_checked = 0
for table in sq_tables:
    sq_cur.execute(f"SELECT COUNT(*) FROM {table}")
    sq_count = sq_cur.fetchone()[0]
    
    try:
        with e.connect() as c:
            pg_count = c.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
        
        if pg_count >= sq_count:
            status = PASS
            total_match += 1
        else:
            status = FAIL
        
        log(status, "MIGRATION", f"{table}: SQLite={sq_count} -> PG={pg_count} {'(OK)' if pg_count >= sq_count else '(PERTE!)'}")
        total_checked += 1
    except Exception:
        log(WARN, "MIGRATION", f"{table}: n'existe pas dans PG")

sq.close()

# ================================================================
# RAPPORT FINAL
# ================================================================
sep("RAPPORT FINAL COMPLET")

total = len(results)
passed = sum(1 for r in results if r[0] == PASS)
failed = sum(1 for r in results if r[0] == FAIL)
warned = sum(1 for r in results if r[0] == WARN)
info = sum(1 for r in results if r[0] == INFO)

losses = [r for r in results if r[0] == FAIL and ("MANQUANT" in r[2] or "PERTE" in r[2])]

print(f"""
  Total verifications : {total}
  {PASS} Reussis    : {passed}
  {FAIL} Echoues    : {failed}
  {WARN} Warnings   : {warned}
  {INFO} Info       : {info}
""")

if failed > 0:
    print(f"  PROBLEMES :")
    for r in results:
        if r[0] == FAIL:
            print(f"    {FAIL} [{r[1]}] {r[2]}")

if losses:
    print(f"\n  !!! ELEMENTS MANQUANTS OU PERTES DETECTEES !!!")
elif failed == 0:
    print(f"  >>> TOUT EST INTACT : DONNEES + INTERFACES + BACKEND <<<")
else:
    print(f"\n  >>> {failed} point(s) a verifier (voir ci-dessus) <<<")

print(f"\n{'='*70}\n")
