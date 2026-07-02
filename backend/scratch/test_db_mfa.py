import os
import sys
from dotenv import load_dotenv

# Charger les variables d'environnement (.env) avant tout import de database
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

# Ajouter le dossier parent au path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
import db_models as db_models

db = SessionLocal()
try:
    user = db.query(db_models.User).first()
    if user:
        print(f"User found: {user.email}")
        print(f"MFA Enabled: {user.mfa_enabled}")
        print(f"MFA Secret: {user.mfa_secret}")
        user.mfa_secret = "TEST_SECRET"
        db.commit()
        print("Commit successful!")
    else:
        print("No user found.")
except Exception as e:
    import traceback
    traceback.print_exc()
finally:
    db.close()
