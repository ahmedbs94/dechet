"""
patch_role_check.py
--------------------
Ajoute la verification role='user' dans :
  1. routers/qr_bins.py  — bloc score citoyen
  2. routers/quiz.py     — submit JSON + submit PDF

Seuls les utilisateurs avec role='user' accumulent des points.
Les admins, collecteurs, educateurs, etc. ne sont jamais credites.
"""
import io, os, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ─────────────────────────────────────────────────────────────────────────────
# PATCH 1 : qr_bins.py  — proteger le bloc de calcul de score citoyen
# ─────────────────────────────────────────────────────────────────────────────
qr_path = os.path.join(BASE, "routers", "qr_bins.py")
with io.open(qr_path, "r", encoding="utf-8") as f:
    qr = f.read()

OLD_QR = (
    "    # \u2500\u2500 4. Calculer les points (type vient du bac, non falsifiable) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "    waste_type = smart_bin.bin_type\n"
    "    points     = calculate_points(waste_type, data.weight_kg)\n"
)

NEW_QR = (
    "    # \u2500\u2500 4. Calculer les points (type vient du bac, non falsifiable) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "    # Seul le role 'user' (citoyen) gagne des points.\n"
    "    # Les admins, collecteurs, educateurs, etc. ne sont jamais credites.\n"
    "    if user.role != \"user\":\n"
    "        raise HTTPException(\n"
    "            status_code=403,\n"
    "            detail=\"Seuls les citoyens (role=user) peuvent gagner des points de tri.\",\n"
    "        )\n"
    "\n"
    "    waste_type = smart_bin.bin_type\n"
    "    points     = calculate_points(waste_type, data.weight_kg)\n"
)

count = qr.count(OLD_QR)
print(f"[qr_bins.py] Patch role-check : {count} correspondance(s)")
if count != 1:
    print("  ERREUR : correspondance non unique ou introuvable")
    sys.exit(1)

qr = qr.replace(OLD_QR, NEW_QR, 1)
with io.open(qr_path, "w", encoding="utf-8") as f:
    f.write(qr)
print("  [OK] Protection role='user' ajoutee dans qr_bins.py")


# ─────────────────────────────────────────────────────────────────────────────
# PATCH 2 : quiz.py  — proteger les deux endpoints de soumission
# ─────────────────────────────────────────────────────────────────────────────
quiz_path = os.path.join(BASE, "routers", "quiz.py")
with io.open(quiz_path, "r", encoding="utf-8") as f:
    quiz = f.read()

# Bloc commun a ajouter apres la verification du quiz (submit JSON)
OLD_JSON = (
    "    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()\n"
    "    if not quiz or quiz.status != \"ready\":\n"
    "        raise HTTPException(status_code=404, detail=\"Quiz non trouv\u00e9 ou pas encore pr\u00eat\")\n"
    "\n"
    "    # V\u00e9rifier si l'utilisateur a d\u00e9j\u00e0 soumis ce quiz\n"
)

NEW_JSON = (
    "    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()\n"
    "    if not quiz or quiz.status != \"ready\":\n"
    "        raise HTTPException(status_code=404, detail=\"Quiz non trouv\u00e9 ou pas encore pr\u00eat\")\n"
    "\n"
    "    # Seul le role 'user' (citoyen) gagne des points de quiz.\n"
    "    if current_user.role != \"user\":\n"
    "        raise HTTPException(\n"
    "            status_code=403,\n"
    "            detail=\"Seuls les citoyens (role=user) peuvent soumettre un quiz et gagner des points.\",\n"
    "        )\n"
    "\n"
    "    # V\u00e9rifier si l'utilisateur a d\u00e9j\u00e0 soumis ce quiz\n"
)

count_json = quiz.count(OLD_JSON)
print(f"[quiz.py] Patch submit JSON : {count_json} correspondance(s)")
if count_json != 1:
    print("  ERREUR : correspondance non unique ou introuvable")
    sys.exit(1)

quiz = quiz.replace(OLD_JSON, NEW_JSON, 1)

# Bloc pour submit PDF
OLD_PDF = (
    "    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()\n"
    "    if not quiz or quiz.status != \"ready\":\n"
    "        raise HTTPException(status_code=404, detail=\"Quiz non trouv\u00e9 ou pas encore pr\u00eat\")\n"
    "\n"
    "    if not file.filename or not file.filename.lower().endswith(\".pdf\"):\n"
)

NEW_PDF = (
    "    quiz = db.query(db_models.Quiz).filter(db_models.Quiz.id == quiz_id).first()\n"
    "    if not quiz or quiz.status != \"ready\":\n"
    "        raise HTTPException(status_code=404, detail=\"Quiz non trouv\u00e9 ou pas encore pr\u00eat\")\n"
    "\n"
    "    # Seul le role 'user' (citoyen) gagne des points de quiz.\n"
    "    if current_user.role != \"user\":\n"
    "        raise HTTPException(\n"
    "            status_code=403,\n"
    "            detail=\"Seuls les citoyens (role=user) peuvent soumettre un quiz et gagner des points.\",\n"
    "        )\n"
    "\n"
    "    if not file.filename or not file.filename.lower().endswith(\".pdf\"):\n"
)

count_pdf = quiz.count(OLD_PDF)
print(f"[quiz.py] Patch submit PDF  : {count_pdf} correspondance(s)")
if count_pdf != 1:
    print("  ERREUR : correspondance non unique ou introuvable")
    sys.exit(1)

quiz = quiz.replace(OLD_PDF, NEW_PDF, 1)

with io.open(quiz_path, "w", encoding="utf-8") as f:
    f.write(quiz)
print("  [OK] Protection role='user' ajoutee dans quiz.py (submit JSON + submit PDF)")

print()
print("=== Verification ===")
with io.open(qr_path, "r", encoding="utf-8") as f:
    qr_check = f.read()
with io.open(quiz_path, "r", encoding="utf-8") as f:
    quiz_check = f.read()

ok1 = 'if user.role != "user":' in qr_check
ok2 = quiz_check.count('if current_user.role != "user":') == 2
print(f"  qr_bins.py role check     : {'OK' if ok1 else 'MANQUANT'}")
print(f"  quiz.py role check x2     : {'OK' if ok2 else 'MANQUANT'}")

if ok1 and ok2:
    print()
    print("[OK] Tous les checks role='user' sont en place !")
    print("     Redemarrez le serveur pour appliquer les changements.")
