import os
import sys
from dotenv import load_dotenv

# Charger les variables d'environnement (.env)
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from main import app
from auth import create_access_token
from database import SessionLocal
import db_models as db_models

# Récupérer un vrai utilisateur du PostgreSQL
db = SessionLocal()
user = db.query(db_models.User).filter(db_models.User.email == "educateur@tridechet.tn").first()
db.close()

if not user:
    print("User not found!")
    sys.exit(1)

# Créer un token valide pour cet utilisateur
token = create_access_token({"sub": user.email})

client = TestClient(app)
try:
    response = client.post(
        "/users/me/mfa/setup",
        headers={"Authorization": f"Bearer {token}"}
    )
    print(f"Status Code: {response.status_code}")
    print(f"Body: {response.text}")
except Exception as e:
    import traceback
    traceback.print_exc()
