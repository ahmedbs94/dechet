"""Diagnostic - compatible SQLite et PostgreSQL"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import db_models  # noqa
from database import SessionLocal
from app.users.models import User

db = SessionLocal()

print("=== FCM TOKENS PAR ROLE ===")
users = db.query(User).filter(
    User.role.in_(["intercommunality", "collector", "admin"])
).order_by(User.role, User.full_name).all()

for u in users:
    if u.fcm_token:
        tok = "OUI: " + u.fcm_token[:35] + "..."
    else:
        tok = "ABSENT"
    print(f"  ID={u.id} | {u.role:20s} | {u.full_name:25s} | FCM: {tok}")

print()
print("=== MESSAGES TABLE (10 derniers) ===")
try:
    from sqlalchemy import text
    rows = db.execute(text(
        "SELECT id, sender_id, receiver_id, is_group_broadcast, SUBSTR(content, 1, 50) as content "
        "FROM messages ORDER BY created_at DESC LIMIT 10"
    )).fetchall()
    for r in rows:
        print(f"  ID={r[0]} | {r[1]}->{r[2]} | broadcast={r[3]} | {r[4]}")
    if not rows:
        print("  Aucun message.")
except Exception as e:
    print(f"  Erreur table messages: {e}")

db.close()
