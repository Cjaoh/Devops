"""test_auth.py — Tests des endpoints d'authentification"""


def test_register_success(client):
    resp = client.post("/api/auth/register", json={
        "email": "newuser@example.com",
        "username": "newuser",
        "password": "SecurePass123!",
        "full_name": "New User",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["email"] == "newuser@example.com"
    assert data["role"] == "user"
    assert "hashed_password" not in data


def test_register_duplicate_email(client):
    payload = {
        "email": "dup@example.com",
        "username": "dup1",
        "password": "Pass123!",
    }
    client.post("/api/auth/register", json=payload)
    resp = client.post("/api/auth/register", json=payload)
    # L'API peut retourner 400 (logique métier) ou 422 (validation Pydantic)
    assert resp.status_code in (400, 422)


def test_register_weak_password(client):
    resp = client.post("/api/auth/register", json={
        "email": "bad@example.com",
        "username": "bad",
        "password": "",
    })
    assert resp.status_code in (400, 422)


def test_login_success(client, normal_user):
    resp = client.post("/api/auth/login", json={
        "email": normal_user["email"],
        "password": normal_user["password"],
    })
    assert resp.status_code == 200
    assert "access_token" in resp.json()
    assert resp.json()["token_type"] == "bearer"


def test_login_wrong_password(client, normal_user):
    resp = client.post("/api/auth/login", json={
        "email": normal_user["email"],
        "password": "WrongPassword!",
    })
    assert resp.status_code == 401


def test_login_unknown_email(client):
    resp = client.post("/api/auth/login", json={
        "email": "nobody@example.com",
        "password": "Pass123!",
    })
    assert resp.status_code == 401


def test_me_authenticated(client, user_token):
    resp = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["email"] == "user@example.com"


def test_me_unauthenticated(client):
    resp = client.get("/api/auth/me")
    assert resp.status_code in (401, 403)
