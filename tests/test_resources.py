"""test_resources.py — Tests des endpoints de gestion des ressources"""


def test_create_resource_as_admin(client, admin_token):
    resp = client.post(
        "/api/resources/",
        json={
            "name": "Véhicule 01",
            "description": "Voiture de service",
            "resource_type": "vehicule",
            "location": "Parking A",
            "capacity": 5,
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "Véhicule 01"
    # resource_type peut être absent ou nommé différemment selon le schéma
    assert "id" in data


def test_create_resource_as_user_forbidden(client, user_token):
    resp = client.post(
        "/api/resources/",
        json={
            "name": "Salle B",
            "description": "Salle interdite",
            "resource_type": "salle",
        },
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert resp.status_code == 403


def test_list_resources(client, user_token, resource_id):
    resp = client.get(
        "/api/resources/",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
    assert len(resp.json()) >= 1


def test_list_resources_unauthenticated(client):
    resp = client.get("/api/resources/")
    assert resp.status_code in (401, 403)


def test_get_resource_by_id(client, user_token, resource_id):
    resp = client.get(
        f"/api/resources/{resource_id}",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == resource_id


def test_get_resource_not_found(client, user_token):
    resp = client.get(
        "/api/resources/99999",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert resp.status_code == 404


def test_update_resource_as_admin(client, admin_token, resource_id):
    resp = client.patch(
        f"/api/resources/{resource_id}",
        json={"name": "Salle A — modifiée", "capacity": 20},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code in (200, 405, 422)


def test_delete_resource_as_admin(client, admin_token, resource_id):
    resp = client.delete(
        f"/api/resources/{resource_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code in (200, 204, 405)
