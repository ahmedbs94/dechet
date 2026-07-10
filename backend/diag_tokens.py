"""
Diagnostic rapide des tokens FCM et des messages entre Mairie et Collecteur.
Exécuter : python diag_tokens.py
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Importer db_models en premier pour initialiser tous les modèles SQLAlchemy
import db_models  # noqa: F401
from database import SessionLocal
from app.users.models import User
from app.messaging.models import Message

db = SessionLocal()

print("=" * 50)
print("TOKENS FCM EN BASE")
print("=" * 50)
users_with_token = db.query(User).filter(
    User.fcm_token.isnot(None), User.fcm_token != ""
).all()
for u in users_with_token:
    tok = (u.fcm_token or "")[:40]
    print(f"  [{u.role}] {u.full_name} → {tok}...")
if not users_with_token:
    print("  ⚠️  Aucun utilisateur avec token FCM en base !")

print()
print("=" * 50)
print("UTILISATEURS INTERCOMMUNALITY")
print("=" * 50)
mairies = db.query(User).filter(User.role == "intercommunality").all()
for u in mairies:
    tok = "OUI → " + (u.fcm_token or "")[:30] + "..." if u.fcm_token else "ABSENT ❌"
    print(f"  ID={u.id} | {u.full_name} | FCM: {tok}")

print()
print("=" * 50)
print("UTILISATEURS COLLECTOR")
print("=" * 50)
collectors = db.query(User).filter(User.role == "collector").all()
for u in collectors:
    tok = "OUI → " + (u.fcm_token or "")[:30] + "..." if u.fcm_token else "ABSENT ❌"
    print(f"  ID={u.id} | {u.full_name} | FCM: {tok}")

print()
print("=" * 50)
print("MESSAGES ENTRE MAIRIE ET COLLECTEUR")
print("=" * 50)
if mairies and collectors:
    mairie_id = mairies[0].id
    coll_id = collectors[0].id
    from sqlalchemy import or_, and_
    msgs = db.query(Message).filter(
        or_(
            and_(Message.sender_id == mairie_id, Message.receiver_id == coll_id),
            and_(Message.sender_id == coll_id, Message.receiver_id == mairie_id),
        )
    ).order_by(Message.created_at.desc()).limit(10).all()
    print(f"  Entre {mairies[0].full_name} (ID={mairie_id}) et {collectors[0].full_name} (ID={coll_id})")
    print(f"  {len(msgs)} message(s) trouvé(s) :")
    for m in msgs:
        broadcast_flag = " [BROADCAST]" if m.is_group_broadcast else ""
        print(f"    [{m.created_at}] {m.sender_id}→{m.receiver_id}{broadcast_flag}: {m.content[:60]}")
else:
    print("  Pas assez d'utilisateurs pour tester.")

db.close()
print()
print("Diagnostic terminé.")
