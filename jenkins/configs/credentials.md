# Guide — Gestion des Credentials Jenkins

## Credentials requis à configurer dans Jenkins
Chemin : **Manage Jenkins → Credentials → System → Global credentials**

---

## 1. `harbor-credentials` — Accès Harbor

| Champ     | Valeur                          |
|-----------|----------------------------------|
| Kind      | Username with password           |
| Scope     | Global                           |
| Username  | admin (ou votre user Harbor)     |
| Password  | mot de passe Harbor              |
| ID        | `harbor-credentials`             |
| Description | Harbor Registry Authentication |

---

## 2. `cosign-private-key` — Clé de signature Cosign

| Champ       | Valeur                          |
|-------------|----------------------------------|
| Kind        | Secret file                      |
| Scope       | Global                           |
| File        | cosign.key (généré par `cosign generate-key-pair`) |
| ID          | `cosign-private-key`             |
| Description | Cosign private key for image signing |

### Générer la paire de clés Cosign :
```bash
cosign generate-key-pair
# Génère : cosign.key (privée) + cosign.pub (publique)
# Uploadez cosign.key dans Jenkins
# Committez cosign.pub dans le dépôt Git (à la racine)
```

---

## 3. `cosign-password` — Mot de passe clé Cosign

| Champ       | Valeur                          |
|-------------|----------------------------------|
| Kind        | Secret text                      |
| Scope       | Global                           |
| Secret      | mot de passe saisi lors du generate-key-pair |
| ID          | `cosign-password`                |
| Description | Cosign key password              |

---

## 4. Variables d'environnement — fichier `.env` sur la VM Server

Le fichier `.env` n'est PAS commité dans Git.  
Il doit être créé manuellement sur la VM Server (dans le répertoire du projet) :

```bash
# /home/deploy/projet-cicd/.env

POSTGRES_DB=reservations
POSTGRES_USER=reserv_user
POSTGRES_PASSWORD=MotDePasseDB_TresSecurise_2024!

SECRET_KEY=une-cle-jwt-aleatoire-256-bits-minimum

HARBOR_URL=https://192.168.1.100
IMAGE_TAG=latest

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=votremail@gmail.com
SMTP_PASSWORD=votre-app-password-gmail
SMTP_FROM=noreply@reservation.local
```

---

## 5. Certificat TLS Harbor (HTTPS auto-signé)

Copier le CA Harbor sur la machine Jenkins :

```bash
# Pour Docker (push/pull)
sudo mkdir -p /etc/docker/certs.d/192.168.1.100/
sudo cp tls/harbor-ca.crt /etc/docker/certs.d/192.168.1.100/ca.crt
sudo systemctl restart docker

# Pour curl / cosign / python
sudo cp tls/harbor-ca.crt /usr/local/share/ca-certificates/harbor-ca.crt
sudo update-ca-certificates
```

---

## Récapitulatif des IDs Credentials Jenkins

| ID                    | Type            | Utilisé dans                    |
|-----------------------|-----------------|---------------------------------|
| `harbor-credentials`  | User/Password   | Push Harbor, Deploy, PolicyCheck |
| `cosign-private-key`  | Secret file     | Stage Sign Image                |
| `cosign-password`     | Secret text     | Stage Sign Image                |
