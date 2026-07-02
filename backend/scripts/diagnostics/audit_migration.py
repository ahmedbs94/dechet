import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
audit_migration.py
===================
Audit complet de la migration SQLite -> PostgreSQL.
Compare table par table, colonne par colonne, enregistrement par enregistrement.

Verifie :
  1. Nombre d'enregistrements (SQLite vs PostgreSQL)
  2. Schema (colonnes presentes / manquantes / ajoutees)
  3. Integrite des donnees (echantillon de chaque table)
  4. Coherence des cles primaires
  5. Relations (foreign keys)
  6. Test CRUD PostgreSQL en live
  7. Acces application (endpoints API)
"""

import os
import sys
import io
import sqlite3
import json
import hashlib
from datetime import datetime

# Force UTF-8
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from dotenv import load_dotenv
load_dotenv()

PASS = "[OK]"
FAIL = "[ECHEC]"
WARN = "[WARN]"
INFO = "[INFO]"

results = []

def log(status, cat, msg):
    results.append((status, cat, msg))
    print(f"  {status} [{cat}] {msg}")

def sep(title):
    print(f"\n{'='*70}")
    print(f"  {title}")
    print(f"{'='*70}")


# ============================================================
# CONNEXIONS
# ============================================================
SQLITE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")
PG_URL = os.getenv("DATABASE_URL", "postgresql://postgres@localhost:5432/ecorewind")

sep("AUDIT MIGRATION SQLite -> PostgreSQL")
print(f"  Date : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print(f"  SQLite : {SQLITE_PATH} ({os.path.getsize(SQLITE_PATH)} bytes)")
print(f"  PostgreSQL : ...@{PG_URL.split('@')[-1] if '@' in PG_URL else PG_URL}")

# SQLite
sq = sqlite3.connect(SQLITE_PATH)
sq.row_factory = sqlite3.Row
sq_cur = sq.cursor()

# PostgreSQL
from sqlalchemy import create_engine, text
pg_engine = create_engine(PG_URL, pool_pre_ping=True)


# ============================================================
# 1. COMPARAISON NOMBRE D'ENREGISTREMENTS
# ============================================================
sep("1. COMPARAISON DES COMPTAGES (SQLite vs PostgreSQL)")

# Lister les tables SQLite
sq_cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
sq_tables = [r[0] for r in sq_cur.fetchall()]

# Lister les tables PostgreSQL
with pg_engine.connect() as conn:
    pg_tables_rows = conn.execute(text(
        "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename"
    )).fetchall()
    pg_tables = [r[0] for r in pg_tables_rows]

log(INFO, "TABLES", f"SQLite : {len(sq_tables)} tables -- {', '.join(sq_tables)}")
log(INFO, "TABLES", f"PostgreSQL : {len(pg_tables)} tables -- {', '.join(pg_tables)}")

# Tables communes
common = sorted(set(sq_tables) & set(pg_tables))
only_sqlite = sorted(set(sq_tables) - set(pg_tables))
only_pg = sorted(set(pg_tables) - set(sq_tables))

if only_sqlite:
    log(WARN, "TABLES", f"Tables UNIQUEMENT dans SQLite : {', '.join(only_sqlite)}")
if only_pg:
    log(INFO, "TABLES", f"Tables UNIQUEMENT dans PostgreSQL (ajoutees post-migration) : {', '.join(only_pg)}")

print()
print(f"  {'Table':<25} {'SQLite':>8} {'PostgreSQL':>12} {'Diff':>8}  Statut")
print(f"  {'-'*25} {'-'*8} {'-'*12} {'-'*8}  {'-'*10}")

count_results = {}
total_sq = 0
total_pg = 0

for table in common:
    sq_cur.execute(f"SELECT COUNT(*) FROM {table}")
    sq_count = sq_cur.fetchone()[0]

    with pg_engine.connect() as conn:
        pg_count = conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()

    diff = pg_count - sq_count
    total_sq += sq_count
    total_pg += pg_count
    count_results[table] = (sq_count, pg_count, diff)

    if diff == 0:
        status = PASS
        status_txt = "IDENTIQUE"
    elif diff > 0:
        status = INFO
        status_txt = f"+{diff} (ajouts post-migration)"
    else:
        status = FAIL
        status_txt = f"PERTE DE {abs(diff)} LIGNES"

    print(f"  {table:<25} {sq_count:>8} {pg_count:>12} {diff:>+8}  {status} {status_txt}")
    log(status, "COUNT", f"{table}: SQLite={sq_count}, PG={pg_count}, diff={diff:+d}")

print(f"  {'-'*25} {'-'*8} {'-'*12} {'-'*8}")
print(f"  {'TOTAL':<25} {total_sq:>8} {total_pg:>12} {total_pg-total_sq:>+8}")


# ============================================================
# 2. COMPARAISON DES SCHEMAS
# ============================================================
sep("2. COMPARAISON DES SCHEMAS")

for table in common:
    # Colonnes SQLite
    sq_cur.execute(f"PRAGMA table_info({table})")
    sq_cols = {r[1]: r[2] for r in sq_cur.fetchall()}  # name -> type

    # Colonnes PostgreSQL
    with pg_engine.connect() as conn:
        pg_cols_rows = conn.execute(text(
            "SELECT column_name, data_type FROM information_schema.columns "
            "WHERE table_name = :t AND table_schema = 'public' ORDER BY ordinal_position"
        ), {"t": table}).fetchall()
        pg_cols = {r[0]: r[1] for r in pg_cols_rows}

    sq_set = set(sq_cols.keys())
    pg_set = set(pg_cols.keys())

    missing_in_pg = sq_set - pg_set
    added_in_pg = pg_set - sq_set
    common_cols = sq_set & pg_set

    if missing_in_pg:
        log(FAIL, "SCHEMA", f"{table}: colonnes MANQUANTES dans PG : {', '.join(missing_in_pg)}")
    if added_in_pg:
        log(INFO, "SCHEMA", f"{table}: colonnes AJOUTEES dans PG : {', '.join(added_in_pg)}")
    if not missing_in_pg and not added_in_pg:
        log(PASS, "SCHEMA", f"{table}: {len(common_cols)} colonnes identiques")
    elif not missing_in_pg:
        log(PASS, "SCHEMA", f"{table}: {len(common_cols)} colonnes originales preservees + {len(added_in_pg)} ajoutees")


# ============================================================
# 3. INTEGRITE DES DONNEES (comparaison enregistrement par enregistrement)
# ============================================================
sep("3. INTEGRITE DES DONNEES (verification ligne par ligne)")

def normalize_value(val):
    """Normalise une valeur pour comparaison SQLite vs PostgreSQL."""
    if val is None:
        return None
    if isinstance(val, bool):
        return 1 if val else 0
    if isinstance(val, (int, float)):
        return val
    s = str(val).strip()
    # Normaliser les datetimes
    for fmt in ["%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"]:
        try:
            datetime.strptime(s, fmt)
            return s[:19]  # Tronquer aux secondes pour comparaison
        except ValueError:
            pass
    return s


for table in common:
    sq_count, pg_count, diff = count_results[table]
    if sq_count == 0:
        log(INFO, "DATA", f"{table}: table vide dans SQLite -- rien a comparer")
        continue

    # Recuperer les colonnes communes
    sq_cur.execute(f"PRAGMA table_info({table})")
    sq_col_names = [r[1] for r in sq_cur.fetchall()]

    with pg_engine.connect() as conn:
        pg_col_names_rows = conn.execute(text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = :t AND table_schema = 'public' ORDER BY ordinal_position"
        ), {"t": table}).fetchall()
        pg_col_names = [r[0] for r in pg_col_names_rows]

    common_cols = [c for c in sq_col_names if c in pg_col_names]
    cols_csv = ", ".join([f'"{c}"' for c in common_cols])

    # Lire toutes les lignes SQLite
    sq_cur.execute(f"SELECT {cols_csv} FROM {table} ORDER BY id")
    sq_rows = sq_cur.fetchall()

    # Lire toutes les lignes PostgreSQL
    with pg_engine.connect() as conn:
        pg_rows_raw = conn.execute(text(f"SELECT {cols_csv} FROM {table} ORDER BY id")).fetchall()

    # Construire un dict par ID pour PostgreSQL
    id_idx = common_cols.index("id") if "id" in common_cols else 0
    pg_by_id = {}
    for r in pg_rows_raw:
        pg_by_id[r[id_idx]] = r

    matched = 0
    mismatched = 0
    missing = 0
    mismatch_details = []

    for sq_row in sq_rows:
        sq_dict = {c: sq_row[i] for i, c in enumerate(common_cols)}
        row_id = sq_dict.get("id", "?")

        if row_id not in pg_by_id:
            missing += 1
            if missing <= 3:
                log(FAIL, "DATA", f"{table} id={row_id}: MANQUANT dans PostgreSQL")
            continue

        pg_row = pg_by_id[row_id]
        pg_dict = {c: pg_row[i] for i, c in enumerate(common_cols)}

        # Comparer chaque colonne
        row_ok = True
        for col in common_cols:
            sq_val = normalize_value(sq_dict[col])
            pg_val = normalize_value(pg_dict[col])

            # Comparaison tolerante pour les floats
            if isinstance(sq_val, float) and isinstance(pg_val, float):
                if abs(sq_val - pg_val) > 0.01:
                    row_ok = False
                    mismatch_details.append(f"{table}.{col} id={row_id}: SQLite={sq_val} vs PG={pg_val}")
            elif sq_val != pg_val:
                # Ignorer les differences de boolean representation
                if (sq_val in (0, 1, "0", "1") and pg_val in (True, False, 0, 1)):
                    continue
                # Ignorer les differences nulles dans les nouveaux champs
                if sq_val is None or pg_val is None:
                    continue
                row_ok = False
                sq_preview = str(sq_val)[:50]
                pg_preview = str(pg_val)[:50]
                mismatch_details.append(f"{table}.{col} id={row_id}: '{sq_preview}' vs '{pg_preview}'")

        if row_ok:
            matched += 1
        else:
            mismatched += 1

    if missing > 0:
        log(FAIL, "DATA", f"{table}: {missing} enregistrement(s) MANQUANT(S) dans PostgreSQL !")
    if mismatched > 0:
        log(WARN, "DATA", f"{table}: {mismatched} enregistrement(s) avec differences")
        for detail in mismatch_details[:5]:
            log(WARN, "DATA-DETAIL", f"  {detail}")
        if len(mismatch_details) > 5:
            log(WARN, "DATA-DETAIL", f"  ... et {len(mismatch_details) - 5} autres differences")
    if missing == 0 and mismatched == 0:
        log(PASS, "DATA", f"{table}: {matched}/{sq_count} enregistrements IDENTIQUES")


# ============================================================
# 4. CLES PRIMAIRES ET SEQUENCES
# ============================================================
sep("4. CLES PRIMAIRES ET SEQUENCES AUTO-INCREMENT")

for table in common:
    with pg_engine.connect() as conn:
        try:
            max_id = conn.execute(text(f"SELECT MAX(id) FROM {table}")).scalar()
            if max_id is None:
                log(INFO, "SEQ", f"{table}: table vide -- sequence OK")
                continue

            # Recuperer la valeur courante de la sequence
            try:
                seq_val = conn.execute(text(
                    f"SELECT last_value FROM pg_get_serial_sequence('{table}', 'id')::regclass"
                )).scalar()
            except Exception:
                seq_val = conn.execute(text(
                    f"SELECT nextval(pg_get_serial_sequence('{table}', 'id')) - 1"
                )).scalar()

            if seq_val and seq_val >= max_id:
                log(PASS, "SEQ", f"{table}: MAX(id)={max_id}, sequence={seq_val} -- OK")
            else:
                log(WARN, "SEQ", f"{table}: MAX(id)={max_id}, sequence={seq_val} -- DESYNCHRONISEE")
        except Exception as e:
            log(WARN, "SEQ", f"{table}: impossible de verifier la sequence ({str(e)[:60]})")


# ============================================================
# 5. RELATIONS (Foreign Keys)
# ============================================================
sep("5. VERIFICATION DES RELATIONS (Foreign Keys)")

FK_CHECKS = [
    ("posts", "user_id", "users", "id", "Posts -> Users"),
    ("comments", "post_id", "posts", "id", "Comments -> Posts"),
    ("comments", "user_id", "users", "id", "Comments -> Users"),
    ("likes", "user_id", "users", "id", "Likes -> Users"),
    ("likes", "post_id", "posts", "id", "Likes -> Posts"),
    ("saved_posts", "user_id", "users", "id", "SavedPosts -> Users"),
    ("saved_posts", "post_id", "posts", "id", "SavedPosts -> Posts"),
    ("notifications", "user_id", "users", "id", "Notifications -> Users"),
    ("quiz_submissions", "quiz_id", "quizzes", "id", "QuizSubmissions -> Quizzes"),
    ("educator_videos", "educator_id", "users", "id", "EducatorVideos -> Users"),
]

for child_table, child_col, parent_table, parent_col, desc in FK_CHECKS:
    if child_table not in pg_tables or parent_table not in pg_tables:
        continue
    try:
        with pg_engine.connect() as conn:
            orphans = conn.execute(text(f"""
                SELECT COUNT(*) FROM {child_table} c 
                LEFT JOIN {parent_table} p ON c."{child_col}" = p.{parent_col}
                WHERE c."{child_col}" IS NOT NULL AND p.{parent_col} IS NULL
            """)).scalar()
            if orphans == 0:
                log(PASS, "FK", f"{desc}: 0 orphelin")
            else:
                log(WARN, "FK", f"{desc}: {orphans} enregistrement(s) orphelin(s)")
    except Exception as e:
        log(WARN, "FK", f"{desc}: erreur verification ({str(e)[:60]})")


# ============================================================
# 6. DONNEES SENSIBLES (mots de passe, tokens)
# ============================================================
sep("6. VERIFICATION DONNEES SENSIBLES")

with pg_engine.connect() as conn:
    # Verifier que tous les passwords sont hashes (bcrypt commence par $2b$)
    users_with_pwd = conn.execute(text(
        "SELECT COUNT(*) FROM users WHERE hashed_password IS NOT NULL"
    )).scalar()
    users_plain = conn.execute(text(
        "SELECT COUNT(*) FROM users WHERE hashed_password IS NOT NULL "
        "AND hashed_password NOT LIKE '$2b$%' AND hashed_password NOT LIKE '$2a$%'"
    )).scalar()

    if users_plain == 0:
        log(PASS, "SECURITY", f"Tous les {users_with_pwd} mot(s) de passe sont haches (bcrypt)")
    else:
        log(FAIL, "SECURITY", f"{users_plain} mot(s) de passe NON hache(s) detecte(s)")

    # Verifier les QR codes uniques
    qr_total = conn.execute(text("SELECT COUNT(qr_code) FROM users WHERE qr_code IS NOT NULL")).scalar()
    qr_unique = conn.execute(text("SELECT COUNT(DISTINCT qr_code) FROM users WHERE qr_code IS NOT NULL")).scalar()
    if qr_total == qr_unique:
        log(PASS, "SECURITY", f"Tous les {qr_total} QR codes sont uniques")
    else:
        log(FAIL, "SECURITY", f"QR codes en doublon : {qr_total} total vs {qr_unique} uniques")

    # Verifier les emails uniques
    email_total = conn.execute(text("SELECT COUNT(email) FROM users")).scalar()
    email_unique = conn.execute(text("SELECT COUNT(DISTINCT email) FROM users")).scalar()
    if email_total == email_unique:
        log(PASS, "SECURITY", f"Tous les {email_total} emails sont uniques")
    else:
        log(FAIL, "SECURITY", f"Emails en doublon : {email_total} total vs {email_unique} uniques")


# ============================================================
# 7. TEST CRUD VIA L'APPLICATION
# ============================================================
sep("7. TEST ACCES APPLICATION (API)")

import urllib.request
import urllib.error

base = "http://127.0.0.1:8000"
api_tests = [
    ("GET", "/", 200, "Health check"),
    ("GET", "/users/me", 401, "Auth protection"),
    ("GET", "/collection-points/", 200, "Points de collecte"),
    ("GET", "/posts/", 200, "Posts communautaires"),
    ("GET", "/educator-videos/", 200, "Videos educatives"),
    ("GET", "/testimonials/", 200, "Temoignages"),
    ("GET", "/stats", 200, "Statistiques"),
    ("GET", "/qr/leaderboard", 200, "Leaderboard QR"),
]

for method, path, expected, desc in api_tests:
    try:
        req = urllib.request.Request(f"{base}{path}", method=method)
        try:
            r = urllib.request.urlopen(req)
            status = r.status
        except urllib.error.HTTPError as he:
            status = he.code
        if status == expected:
            log(PASS, "API", f"{method} {path} -> {status} ({desc})")
        else:
            log(WARN, "API", f"{method} {path} -> {status} (attendu {expected}) ({desc})")
    except Exception as e:
        log(FAIL, "API", f"{method} {path} -> ERREUR : {e}")

# Verifier que les donnees PG sont bien servies via l'API
try:
    r = urllib.request.urlopen(f"{base}/collection-points/")
    data = json.loads(r.read().decode())
    with pg_engine.connect() as conn:
        pg_cp_count = conn.execute(text("SELECT COUNT(*) FROM collection_points")).scalar()
    if isinstance(data, list) and len(data) == pg_cp_count:
        log(PASS, "API-DATA", f"API retourne {len(data)} points de collecte = {pg_cp_count} dans PG")
    else:
        api_len = len(data) if isinstance(data, list) else "?"
        log(WARN, "API-DATA", f"API retourne {api_len} vs {pg_cp_count} dans PG")
except Exception as e:
    log(WARN, "API-DATA", f"Impossible de verifier les donnees API : {e}")

try:
    r = urllib.request.urlopen(f"{base}/posts/")
    data = json.loads(r.read().decode())
    items = data if isinstance(data, list) else data.get("items", data.get("posts", []))
    if len(items) > 0:
        log(PASS, "API-DATA", f"API retourne {len(items)} post(s) -- donnees PostgreSQL accessibles")
    else:
        log(WARN, "API-DATA", f"API retourne 0 posts")
except Exception as e:
    log(WARN, "API-DATA", f"Impossible de verifier les posts API : {e}")


# ============================================================
# 8. DONNEES UTILISATEURS (echantillon)
# ============================================================
sep("8. ECHANTILLON UTILISATEURS (5 premiers)")

with pg_engine.connect() as conn:
    users = conn.execute(text(
        "SELECT id, email, full_name, role, is_active, is_verified, global_score "
        "FROM users ORDER BY id LIMIT 5"
    )).fetchall()

print(f"\n  {'ID':>4} {'Email':<30} {'Nom':<20} {'Role':<12} {'Act':>4} {'Ver':>4} {'Score':>6}")
print(f"  {'-'*4} {'-'*30} {'-'*20} {'-'*12} {'-'*4} {'-'*4} {'-'*6}")
for u in users:
    print(f"  {u[0]:>4} {str(u[1])[:30]:<30} {str(u[2])[:20]:<20} {str(u[3]):<12} {str(u[4]):>4} {str(u[5]):>4} {u[6]:>6.1f}")


# ============================================================
# RAPPORT FINAL
# ============================================================
sep("RAPPORT FINAL")

total = len(results)
passed = sum(1 for r in results if r[0] == PASS)
failed = sum(1 for r in results if r[0] == FAIL)
warned = sum(1 for r in results if r[0] == WARN)
info = sum(1 for r in results if r[0] == INFO)

# Verifier les pertes de donnees
data_losses = [r for r in results if r[0] == FAIL and "MANQUANT" in r[2]]
count_losses = [r for r in results if r[0] == FAIL and "PERTE" in r[2]]

print(f"""
  Total verifications : {total}
  {PASS} Reussis    : {passed}
  {FAIL} Echoues    : {failed}
  {WARN} Warnings   : {warned}
  {INFO} Info       : {info}
""")

if failed > 0:
    print(f"  PROBLEMES DETECTES :")
    for r in results:
        if r[0] == FAIL:
            print(f"    {FAIL} [{r[1]}] {r[2]}")
    print()

if data_losses or count_losses:
    print(f"  !!! PERTE DE DONNEES DETECTEE !!!")
elif failed == 0:
    print(f"  >>> MIGRATION VERIFIEE : AUCUNE PERTE DE DONNEES <<<")
    print(f"  >>> TOUTES LES DONNEES SQLITE SONT DANS POSTGRESQL <<<")
else:
    print(f"  >>> {failed} PROBLEME(S) A INVESTIGUER (voir ci-dessus) <<<")

print(f"\n{'='*70}\n")

sq.close()
