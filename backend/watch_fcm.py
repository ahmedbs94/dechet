"""
Surveille en temps réel l'arrivée des FCM tokens dans la BDD.
Lance ce script PENDANT que l'utilisateur se connecte sur le téléphone.
"""
import sys, os, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, '.')

from database import engine
from sqlalchemy import text
from services.fcm_push_service import send_push_to_user, _init_fcm
from database import SessionLocal

_init_fcm()

print("Surveillance des FCM tokens... (Ctrl+C pour arrêter)")
print("Connecte-toi sur le téléphone maintenant!\n")

last_count = 0
MAX_WAIT = 120  # 2 minutes max

for i in range(MAX_WAIT):
    with engine.connect() as conn:
        r = conn.execute(text(
            "SELECT id, full_name, role, fcm_token FROM users "
            "WHERE fcm_token IS NOT NULL AND fcm_token != '' "
        ))
        users = r.fetchall()
        count = len(users)
    
    if count > last_count:
        print(f"\n✅ NOUVEAU TOKEN DÉTECTÉ ! ({count} utilisateur(s) avec token)")
        for u in users:
            print(f"  → {u[1]} ({u[2]}): {u[3][:30]}...")
        
        # Envoyer push de test immédiatement
        print("\n📤 Envoi push de test...")
        db = SessionLocal()
        try:
            for u in users:
                ok = send_push_to_user(
                    db, u[0],
                    title="🔔 EcoRewind - Push activé !",
                    body=f"Bonjour {u[1]} ! Vos notifications push fonctionnent.",
                    data={"type": "info"}
                )
                print(f"  Push vers {u[1]}: {'✅ Envoyé' if ok else '❌ Echec'}")
        finally:
            db.close()
        last_count = count
    else:
        # Afficher un point toutes les 5 secondes
        if i % 5 == 0:
            print(f"\r[{i}s] En attente... ({count} tokens) ", end="", flush=True)
    
    time.sleep(1)

print("\n\nFin de la surveillance.")
