# Projet CI/CD Sécurisé — Gestion de Réservation

## Description

Pipeline DevSecOps complet pour une application de **gestion de réservation de ressources** (véhicules, équipements, salles).

## Architecture

```
Developer → Jenkins (CI/CD)
              │
              ├── SAST (Bandit + Semgrep)
              ├── Secrets Scan (Gitleaks)
              ├── Unit Tests (pytest)
              ├── Build Docker Image
              ├── Dependency Scan (OWASP)
              ├── Container Scan (Trivy)
              ├── Sign Image (Cosign)
              ├── Push → Harbor (192.168.43.133)
              ├── Harbor Policy Check
              ├── Verify Signature
              └── Deploy via Ansible → VM Server (192.168.43.130)
```

## Stack technique

| Composant       | Outil                         |
|-----------------|-------------------------------|
| CI/CD           | Jenkins                       |
| Registry        | Harbor (HTTPS, 192.168.43.133)|
| Runtime         | VM Server Ubuntu (192.168.43.130) |
| Backend         | Python 3.11 + FastAPI         |
| Base de données | PostgreSQL 15                 |
| Auth            | JWT (python-jose + bcrypt)    |
| Email           | SMTP (smtplib)                |
| Reverse proxy   | Nginx                         |
| Conteneurisation| Docker + Docker Compose       |
| SAST            | Bandit + Semgrep              |
| Secrets         | Gitleaks                      |
| Scan dépendances| OWASP Dependency Check        |
| Scan image      | Trivy                         |
| Signature       | Cosign                        |
| Déploiement     | Ansible                       |

## Prérequis Jenkins (Credentials)

| ID Credential              | Type                | Contenu                          |
|----------------------------|---------------------|----------------------------------|
| `harbor-robot-credentials` | Username/Password   | `robot$jenkins-robot` + token    |
| `cosign-private-key`       | Secret file         | Clé privée Cosign                |
| `cosign-password`          | Secret text         | Mot de passe clé Cosign          |
| `ansible-ssh-key`          | SSH Private Key     | Clé privée SSH vers VM Server    |

## Installation rapide

### 1. Cloner le projet

```bash
git clone <url-repo>
cd projet-cicd-securise
```

### 2. Configurer les variables d'environnement

```bash
cp .env.example .env
# Éditer .env avec vos vraies valeurs
```

### 3. Certificat Harbor (HTTPS auto-signé)

```bash
# Sur la machine Jenkins :
sudo mkdir -p /etc/docker/certs.d/192.168.43.133
sudo cp tls/harbor-ca.crt /etc/docker/certs.d/192.168.43.133/ca.crt
sudo systemctl restart docker

# Pour Cosign / curl :
sudo cp tls/harbor-ca.crt /usr/local/share/ca-certificates/harbor-ca.crt
sudo update-ca-certificates
```

### 4. Clé SSH Jenkins → VM Server

```bash
# Sur le container Jenkins :
ssh-keygen -t ed25519 -C "jenkins-ansible" -f ~/.ssh/id_ansible -N ""
ssh-copy-id -i ~/.ssh/id_ansible.pub lms@192.168.43.130
```

### 5. Lancer le pipeline

Pousser sur la branche `main` déclenche automatiquement le pipeline Jenkins.

## Structure du projet

```
projet-cicd-securise/
├── Jenkinsfile
├── docker-compose.yml
├── .env.example
├── src/                    # Application FastAPI
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── models/
│   ├── schemas/
│   ├── routers/
│   ├── services/
│   └── utils/
├── frontend/               # Interface web
├── docker/                 # Dockerfile + nginx.conf
├── tests/                  # Tests pytest
├── scripts/                # Scripts DevSecOps
├── ansible/                # Déploiement automatique
├── harbor/                 # Politiques Harbor
├── tls/                    # Certificat CA Harbor
└── docs/                   # Documentation
```

## API Endpoints

| Méthode | Route                       | Auth   | Description                  |
|---------|-----------------------------|--------|------------------------------|
| POST    | /api/auth/register          | Non    | Créer un compte               |
| POST    | /api/auth/login             | Non    | Connexion (JWT)               |
| GET     | /api/resources              | Oui    | Liste des ressources          |
| POST    | /api/resources              | Admin  | Créer une ressource           |
| GET     | /api/reservations           | Oui    | Mes réservations              |
| POST    | /api/reservations           | Oui    | Créer une réservation         |
| DELETE  | /api/reservations/{id}      | Oui    | Annuler une réservation       |
| GET     | /health                     | Non    | Healthcheck                   |

## Sécurité

- Authentification JWT (access token 60 min)
- Mots de passe hashés avec bcrypt
- Validation des entrées via Pydantic
- CORS configuré
- Scan SAST à chaque build
- Images signées avec Cosign
- Scan vulnérabilités Trivy + Harbor

## Critères d'évaluation

| Critère                                   | Poids |
|-------------------------------------------|-------|
| Pipeline CI/CD complet et automatisé      | 30%   |
| Sécurisation (SAST, scan, signature)      | 25%   |
| Gestion secrets + conformité OWASP        | 20%   |
| Déploiement automatisé sécurisé           | 15%   |
| Rapport et démonstration technique        | 10%   |
