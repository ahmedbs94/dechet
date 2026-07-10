"""
restore_poubelles_firebase.py
─────────────────────────────
Script de récupération d'urgence : recrée /poubelles/ dans Firebase RTDB
depuis les SmartBins stockés en base de données locale (SQLite/PostgreSQL).

Exécution (depuis le dossier backend/) :
    python restore_poubelles_firebase.py

Si FIREBASE_DATABASE_URL n'est pas dans .env, le script demande l'URL
interactivement.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ── Chargement .env ───────────────────────────────────────────────────────────
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))
    print("[ENV] .env chargé.")
except ImportError:
    print("[ENV] python-dotenv non installé, variables d'environnement brutes utilisées.")

# ── Si FIREBASE_DATABASE_URL absent → demander interactivement ────────────────
db_url = os.getenv("FIREBASE_DATABASE_URL", "").strip()
if not db_url:
    print("\n⚠️  FIREBASE_DATABASE_URL non trouvé dans .env")
    print("   Exemple : https://ecorewind-xxxxx-default-rtdb.europe-west1.firebasedatabase.app")
    db_url = input("   Entrez l'URL de votre Firebase RTDB : ").strip()
    if not db_url:
        print("[ERREUR] URL vide. Abandon.")
        sys.exit(1)
    # Injecter en mémoire pour que _init_firebase() le trouve
    os.environ["FIREBASE_DATABASE_URL"] = db_url

print(f"[Firebase] URL : {db_url}")

# ── Imports projet ────────────────────────────────────────────────────────────
# On importe les modèles pour initialiser SQLAlchemy correctement
try:
    import app.users.models
    import app.posts.models
    import app.qr_bins.models
    import app.collection_points.models
except Exception as e:
    print(f"[WARN] Certains modèles non chargés : {e}")

from database import SessionLocal
from services.firebase_service import _init_firebase, update_bin_status

# ── Initialisation Firebase ────────────────────────────────────────────────────
print("\n[Firebase] Initialisation...")
if not _init_firebase():
    print("[ERREUR] Firebase non disponible. Vérifiez :")
    print("  1. firebase_credentials.json est dans backend/")
    print("  2. FIREBASE_DATABASE_URL est correct")
    sys.exit(1)
print("[Firebase] OK Connexion Firebase\n")

# ── Lecture des SmartBins depuis la DB ────────────────────────────────────────
print("=" * 60)
print("  RESTAURATION : /poubelles/ dans Firebase RTDB")
print("=" * 60)

db = SessionLocal()
ok = 0
err = 0

try:
    from app.qr_bins.models import SmartBin
    bins = db.query(SmartBin).all()

    if not bins:
        print("[WARN] Aucune poubelle trouvee en base de donnees.")
        print("       Voulez-vous creer les poubelles de demonstration ? (o/n)")
        choice = input("   > ").strip().lower()
        if choice == 'o':
            # Donnees de demo par defaut
            demo_bins = [
                ("BIN-PLASTIQUE-001", 0.0, "vide"),
                ("BIN-VERRE-001",     0.0, "vide"),
                ("BIN-PAPIER-001",    0.0, "vide"),
                ("BIN-METAL-001",     0.0, "vide"),
                ("BIN-ORGANIQUE-001", 0.0, "vide"),
                ("BIN-GENERAL-001",   0.0, "vide"),
            ]
            for bin_code, poids, etat in demo_bins:
                success = update_bin_status(bin_code, poids, etat)
                if success:
                    print(f"  [OK]  {bin_code} -> Firebase /poubelles/{bin_code}")
                    ok += 1
                else:
                    print(f"  [ERR] {bin_code} -> Echec ecriture Firebase")
                    err += 1
        else:
            print("Abandon.")
            sys.exit(0)
    else:
        print(f"[DB] {len(bins)} poubelle(s) trouvee(s) en base\n")
        for b in bins:
            etat  = getattr(b, 'current_status', None) or getattr(b, 'status', 'vide')
            if etat in ('active', 'inactive', 'maintenance'):
                etat_firebase = 'en_maintenance' if etat == 'maintenance' else 'vide'
            elif etat in ('vide', 'mi-plein', 'plein', 'en_maintenance'):
                etat_firebase = etat
            else:
                etat_firebase = 'vide'

            poids = getattr(b, 'current_weight_kg', None) or 0.0

            success = update_bin_status(b.bin_code, poids, etat_firebase)
            if success:
                print(f"  [OK]  {b.bin_code} ({getattr(b, 'bin_type', '?')}) -> poids={poids}kg, etat={etat_firebase}")
                ok += 1
            else:
                print(f"  [ERR] {b.bin_code} -> Echec ecriture Firebase")
                err += 1

finally:
    db.close()

print("\n" + "=" * 60)
print(f"  [OK] {ok} poubelle(s) restauree(s) dans Firebase")
if err:
    print(f"  [ERR] {err} poubelle(s) en erreur")
print(f"  Firebase RTDB -> /poubelles/")
print("=" * 60)
