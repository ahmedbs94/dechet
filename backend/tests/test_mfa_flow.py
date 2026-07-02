"""
Tests unitaires pour le flux d'authentification forte (MFA TOTP)
===============================================================
Lancer avec : pytest tests/test_mfa_flow.py -v
"""
import pytest
import pyotp
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base, get_db

SQLALCHEMY_TEST_URL = "sqlite:///./test_mfa.db"
engine_test = create_engine(SQLALCHEMY_TEST_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine_test)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(scope="module")
def client():
    from main import app
    Base.metadata.create_all(bind=engine_test)
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(bind=engine_test)


def test_mfa_full_flow(client):
    email = "mfa_test@tridechet.tn"
    password = "SuperPassword123!"
    full_name = "MFA Test User"

    # 1. Inscription d'un nouvel utilisateur
    r = client.post("/register", json={
        "email": email,
        "full_name": full_name,
        "password": password,
        "role": "user"
    })
    assert r.status_code == 200
    assert r.json()["email"] == email

    # 2. Première connexion classique (MFA désactivé par défaut)
    r = client.post("/token", data={"username": email, "password": password})
    assert r.status_code == 200
    data = r.json()
    assert "access_token" in data
    assert "status" not in data  # Pas de redirection MFA
    token = data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 3. Récupération des infos de profil
    r = client.get("/users/me", headers=headers)
    assert r.status_code == 200
    assert r.json()["mfa_enabled"] is False

    # 4. Initialisation du MFA (/users/me/mfa/setup)
    r = client.post("/users/me/mfa/setup", headers=headers)
    assert r.status_code == 200
    setup_data = r.json()
    assert "secret" in setup_data
    assert "otpauth_url" in setup_data
    secret = setup_data["secret"]
    assert "EcoRewind" in setup_data["otpauth_url"]

    # 5. Tentative d'activation avec un code invalide
    r = client.post("/users/me/mfa/verify-enable", json={"code": "000000"}, headers=headers)
    assert r.status_code == 400
    assert "incorrect" in r.json()["detail"].lower()

    # 6. Activation de la MFA avec le bon code
    totp = pyotp.TOTP(secret)
    valid_code = totp.now()
    r = client.post("/users/me/mfa/verify-enable", json={"code": valid_code}, headers=headers)
    assert r.status_code == 200
    assert r.json()["mfa_enabled"] is True

    # 7. Vérification de la prise en compte sur le profil
    r = client.get("/users/me", headers=headers)
    assert r.status_code == 200
    assert r.json()["mfa_enabled"] is True

    # 8. Re-connexion: Doit demander la double authentification
    r = client.post("/token", data={"username": email, "password": password})
    assert r.status_code == 200
    login_data = r.json()
    assert login_data["status"] == "mfa_required"
    assert "mfa_token" in login_data
    assert "access_token" not in login_data
    mfa_token = login_data["mfa_token"]

    # 9. Tenter d'accéder au profil avec le jeton MFA temporaire (doit être rejeté !)
    r = client.get("/users/me", headers={"Authorization": f"Bearer {mfa_token}"})
    assert r.status_code == 401
    assert "verification pending" in r.json()["detail"].lower()

    # 10. Valider la connexion MFA avec un mauvais code
    r = client.post("/auth/mfa/verify", json={"mfa_token": mfa_token, "code": "999999"})
    assert r.status_code == 401
    assert "incorrect" in r.json()["detail"].lower()

    # 11. Valider la connexion MFA avec le bon code
    valid_code_2 = totp.now()
    r = client.post("/auth/mfa/verify", json={"mfa_token": mfa_token, "code": valid_code_2})
    assert r.status_code == 200
    final_data = r.json()
    assert "access_token" in final_data
    assert final_data["token_type"] == "bearer"
    new_token = final_data["access_token"]
    new_headers = {"Authorization": f"Bearer {new_token}"}

    # 12. Accès au profil avec le nouveau token final (doit fonctionner)
    r = client.get("/users/me", headers=new_headers)
    assert r.status_code == 200
    assert r.json()["mfa_enabled"] is True

    # 13. Tentative de désactivation avec un mauvais mot de passe
    r = client.post("/users/me/mfa/disable", json={"password": "wrongpassword"}, headers=new_headers)
    assert r.status_code == 400
    assert "incorrect" in r.json()["detail"].lower()

    # 14. Désactivation réussie de la MFA
    r = client.post("/users/me/mfa/disable", json={"password": password}, headers=new_headers)
    assert r.status_code == 200
    assert r.json()["mfa_enabled"] is False

    # 15. Vérification finale: connexion classique directe
    r = client.post("/token", data={"username": email, "password": password})
    assert r.status_code == 200
    assert "access_token" in r.json()
    assert "status" not in r.json()
