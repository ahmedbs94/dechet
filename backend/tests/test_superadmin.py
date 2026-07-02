import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database import Base, get_db
import db_models

SQLALCHEMY_TEST_URL = "sqlite:///./test_superadmin.db"
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

def test_superadmin_vs_admin_privileges(client):
    # 1. Create a superadmin user directly in database
    db = TestingSessionLocal()
    from app.auth.service import get_password_hash
    
    superadmin_user = db_models.User(
        email="super@eco.tn",
        full_name="Super Admin",
        hashed_password=get_password_hash("superpass123"),
        role="superadmin",
        is_active=True
    )
    admin_user = db_models.User(
        email="admin_std@eco.tn",
        full_name="Standard Admin",
        hashed_password=get_password_hash("adminpass123"),
        role="admin",
        is_active=True
    )
    regular_user = db_models.User(
        email="citizen@eco.tn",
        full_name="Citizen User",
        hashed_password=get_password_hash("citizenpass123"),
        role="user",
        is_active=True
    )
    
    db.add(superadmin_user)
    db.add(admin_user)
    db.add(regular_user)
    db.commit()
    db.refresh(superadmin_user)
    db.refresh(admin_user)
    db.refresh(regular_user)
    
    # 2. Get tokens
    # Login Superadmin
    r = client.post("/token", data={"username": "super@eco.tn", "password": "superpass123"})
    assert r.status_code == 200
    superadmin_token = r.json()["access_token"]
    
    # Login Admin
    r = client.post("/token", data={"username": "admin_std@eco.tn", "password": "adminpass123"})
    assert r.status_code == 200
    admin_token = r.json()["access_token"]

    # 3. Test list users
    # Superadmin lists all
    r = client.get("/users", headers={"Authorization": f"Bearer {superadmin_token}"})
    assert r.status_code == 200
    superadmin_list = r.json()
    assert len(superadmin_list) >= 3
    assert any(u["role"] == "superadmin" for u in superadmin_list)
    assert any(u["role"] == "admin" for u in superadmin_list)
    assert any(u["role"] == "user" for u in superadmin_list)
    
    # Standard Admin lists only non-admins
    r = client.get("/users", headers={"Authorization": f"Bearer {admin_token}"})
    assert r.status_code == 200
    admin_list = r.json()
    assert not any(u["role"] == "superadmin" for u in admin_list)
    assert not any(u["role"] == "admin" for u in admin_list)
    assert any(u["role"] == "user" for u in admin_list)

    # 4. Test Create User with admin role
    # Admin tries to create another admin -> 403
    r = client.post(
        "/admin/users",
        json={"email": "newadmin@eco.tn", "full_name": "New Admin", "role": "admin", "password": "password123"},
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert r.status_code == 403
    
    # Superadmin creates an admin -> 200
    r = client.post(
        "/admin/users",
        json={"email": "newadmin@eco.tn", "full_name": "New Admin", "role": "admin", "password": "password123"},
        headers={"Authorization": f"Bearer {superadmin_token}"}
    )
    assert r.status_code == 200
    new_admin_id = r.json()["id"]

    # 5. Test Update User role
    # Admin tries to update role of citizen to admin -> 403
    r = client.put(
        f"/admin/users/{regular_user.id}",
        json={"role": "admin"},
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert r.status_code == 403

    # Admin tries to update name of another admin -> 403
    r = client.put(
        f"/admin/users/{new_admin_id}",
        json={"full_name": "Attempted update"},
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert r.status_code == 403

    # Superadmin updates role of citizen to pointManager -> 200
    r = client.put(
        f"/admin/users/{regular_user.id}",
        json={"role": "pointManager"},
        headers={"Authorization": f"Bearer {superadmin_token}"}
    )
    assert r.status_code == 200
    assert r.json()["role"] == "pointManager"

    # 6. Test Delete User
    # Admin tries to delete an admin -> 403
    r = client.delete(
        f"/admin/users/{new_admin_id}",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert r.status_code == 403

    # Superadmin deletes the admin -> 200
    r = client.delete(
        f"/admin/users/{new_admin_id}",
        headers={"Authorization": f"Bearer {superadmin_token}"}
    )
    assert r.status_code == 200

    db.close()
