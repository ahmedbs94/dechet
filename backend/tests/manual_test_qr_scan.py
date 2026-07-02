import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

"""
test_qr_scan.py — Test complet du système QR Poubelle + Firebase
Exécuter avec : python -X utf8 test_qr_scan.py
"""
import requests
import psycopg2
import json

BASE_URL = "http://127.0.0.1:8000"

print("=" * 60)
print("  TEST SYSTEME QR POUBELLE + FIREBASE")
print("=" * 60)

# ── Étape 1 : Récupérer un citoyen avec QR code ──────────────────
print("\n[1] Recherche d'un citoyen avec QR code dans PostgreSQL...")
try:
    conn = psycopg2.connect("postgresql://postgres@localhost:5432/ecorewind")
    cur = conn.cursor()
    cur.execute("""
        SELECT id, full_name, email, qr_code, global_score
        FROM users
        WHERE qr_code IS NOT NULL AND qr_code != ''
        AND role = 'user'
        LIMIT 3
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    if not rows:
        print("[WARN] Aucun citoyen avec QR code trouvé.")
        print("       Ajoutez un utilisateur via /docs ou l'app Flutter.")
        exit(1)

    print(f"[OK]  {len(rows)} citoyen(s) trouvé(s) :")
    for r in rows:
        print(f"      id={r[0]} | {r[1]} | qr={r[3][:20]}... | score={r[4]}")

    # Prendre le premier
    user_id, user_name, user_email, user_qr, score_before = rows[0]
    print(f"\n[>]  Citoyen selectionne : {user_name} (score actuel : {score_before})")

except Exception as e:
    print(f"[ERREUR] PostgreSQL : {e}")
    exit(1)

# ── Étape 2 : Appeler POST /qr/scan-bin ─────────────────────────
print("\n[2] Envoi du scan QR a l'API...")

payload = {
    "qr_code": user_qr,
    "waste_type": "plastique",
    "bin_id": "BIN-TEST-001"
}

try:
    resp = requests.post(
        f"{BASE_URL}/qr/scan-bin",
        json=payload,
        timeout=15
    )

    if resp.status_code == 200:
        data = resp.json()
        print("[OK]  Scan reussi !")
        print(f"      Points gagnes    : +{data['points_earned']} pts")
        print(f"      Score avant      : {data['score_before']} pts")
        print(f"      Score apres      : {data['score_after']} pts")
        print(f"      Firebase synced  : {data['firebase_synced']}")
        print(f"      Message          : {data['message']}")

        if data['firebase_synced']:
            print("\n[FIREBASE] Score mis a jour en temps reel !")
            print(f"           Noeud : /scores/{data['user_id']}")
            print(f"           URL   : https://ecorewind-6b5d6-default-rtdb.europe-west1.firebasedatabase.app/scores/{data['user_id']}.json")
        else:
            print("\n[WARN] Firebase non synced — verifier firebase_credentials.json")
    else:
        print(f"[ERREUR] HTTP {resp.status_code} : {resp.text}")

except requests.exceptions.ConnectionError:
    print("[ERREUR] Backend non accessible — uvicorn est-il lance ?")
except Exception as e:
    print(f"[ERREUR] {e}")

# ── Étape 3 : Vérifier le leaderboard ───────────────────────────
print("\n[3] Verification du leaderboard...")
try:
    resp = requests.get(f"{BASE_URL}/qr/leaderboard?limit=3", timeout=5)
    if resp.status_code == 200:
        data = resp.json()
        print("[OK]  Top 3 citoyens :")
        for entry in data.get("leaderboard", []):
            print(f"      #{entry['rank']} {entry['full_name']} — {entry['global_score']} pts")
    else:
        print(f"[WARN] Leaderboard : HTTP {resp.status_code}")
except Exception as e:
    print(f"[WARN] Leaderboard : {e}")

print("\n" + "=" * 60)
print("  TEST TERMINE")
print("=" * 60)
