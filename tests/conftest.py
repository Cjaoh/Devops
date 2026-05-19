"""
conftest.py — Fixtures pytest pour les tests de l'API
Utilise starlette.testclient (sync) + SQLite
Aucun import direct des modèles — tout passe par l'API
"""
import pytest
from starlette.testclient import TestClient
from sqlalchemy import text

from src.main import app
from src.database import Base, engine, SessionLocal


# ──────────────────────────────────────────────
# Setup base de données
# ──────────────────────────────────────────────

@pytest.fixture(scope="session", autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(autouse=True)
def clean_tables():
    yield
    db = SessionLocal()
    try:
        for table in reversed(Base.metadata.sorted_tables):
            db.execute(table.delete())
        db.commit()
    finally:
        db.close()


# ──────────────────────────────────────────────
# Client HTTP
# ──────────────────────────────────────────────

@pytest.fixture
def client():
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c


# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────

def _register(client, email, username, password, full_name="Test"):
    resp = client.post("/api/auth/register", json={
        "email": email,
        "username": username,
        "password": password,
        "full_name": full_name,
    })
    assert resp.status_code == 201, f"register failed: {resp.text}"
    return resp.json()


def _login(client, email, password):
    resp = client.post("/api/auth/login", json={
        "email": email,
        "password": password,
    })
    assert resp.status_code == 200, f"login failed: {resp.text}"
    return resp.json()["access_token"]


def _promote_to_admin(email):
    """Élève un utilisateur au rôle admin via SQL brut (pas d'import enum)."""
    db = SessionLocal()
    try:
        db.execute(
            text("UPDATE users SET role = 'admin' WHERE email = :email"),
            {"email": email},
        )
        db.commit()
    finally:
        db.close()


# ──────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────

@pytest.fixture
def normal_user(client):
    email, password = "user@example.com", "UserPass123!"
    _register(client, email, "testuser", password)
    return {"email": email, "password": password}


@pytest.fixture
def admin_user(client):
    email, password = "admin@example.com", "AdminPass123!"
    _register(client, email, "adminuser", password)
    _promote_to_admin(email)
    return {"email": email, "password": password}


@pytest.fixture
def user_token(client, normal_user):
    return _login(client, normal_user["email"], normal_user["password"])


@pytest.fixture
def admin_token(client, admin_user):
    return _login(client, admin_user["email"], admin_user["password"])


@pytest.fixture
def resource_id(client, admin_token):
    resp = client.post(
        "/api/resources/",
        json={
            "name": "Salle de réunion A",
            "description": "Grande salle",
            "resource_type": "salle",
            "location": "Batiment principal",
            "capacity": 10,
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 201, f"resource creation failed: {resp.text}"
    return resp.json()["id"]
