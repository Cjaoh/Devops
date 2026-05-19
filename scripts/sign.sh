#!/usr/bin/env bash
# =============================================================================
# sign.sh — Signature cryptographique de l'image Docker
# Outil : Cosign (Sigstore)
# Usage : ./scripts/sign.sh <IMAGE:TAG>
#
# Variables d'environnement attendues (injectées par Jenkins Credentials) :
#   COSIGN_KEY      — Chemin vers la clé privée Cosign (.key)
#   COSIGN_PASSWORD — Mot de passe de la clé privée
# =============================================================================
set -euo pipefail

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
    echo "[ERROR] Usage : $0 <IMAGE:TAG>"
    exit 1
fi

COSIGN_VERSION="${COSIGN_VERSION:-2.2.3}"
COSIGN_KEY="${COSIGN_KEY:-}"
COSIGN_PASSWORD="${COSIGN_PASSWORD:-}"

echo "================================================================"
echo " Signature de l'image — Cosign"
echo " Image : ${IMAGE}"
echo "================================================================"

# ──────────────────────────────────────────────
# 1. Validation des prérequis
# ──────────────────────────────────────────────
if [ -z "$COSIGN_KEY" ]; then
    echo "[ERROR] Variable COSIGN_KEY non définie (chemin vers la clé privée)."
    exit 1
fi

if [ ! -f "$COSIGN_KEY" ]; then
    echo "[ERROR] Fichier de clé Cosign introuvable : ${COSIGN_KEY}"
    exit 1
fi

if [ -z "$COSIGN_PASSWORD" ]; then
    echo "[ERROR] Variable COSIGN_PASSWORD non définie."
    exit 1
fi

# ──────────────────────────────────────────────
# 2. Installation de Cosign si absent
# ──────────────────────────────────────────────
if ! command -v cosign &>/dev/null; then
    echo "[INFO] Cosign non trouvé. Installation de la version ${COSIGN_VERSION}..."

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  COSIGN_ARCH="amd64" ;;
        aarch64) COSIGN_ARCH="arm64" ;;
        *)       echo "[ERROR] Architecture non supportée : $ARCH"; exit 1 ;;
    esac

    COSIGN_URL="https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${COSIGN_ARCH}"

    echo "[INFO] Téléchargement : $COSIGN_URL"
    curl -sSL "$COSIGN_URL" -o /usr/local/bin/cosign
    chmod +x /usr/local/bin/cosign

    echo "[OK] Cosign installé : $(cosign version 2>/dev/null | head -1)"
else
    echo "[OK] Cosign disponible : $(cosign version 2>/dev/null | head -1)"
fi

# ──────────────────────────────────────────────
# 3. Récupération du digest SHA256 de l'image
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Récupération du digest SHA256 de l'image..."

# On utilise le digest pour signer une référence immuable
IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null || true)

if [ -z "$IMAGE_DIGEST" ]; then
    echo "[INFO] Digest non disponible localement — signature par tag."
    IMAGE_REF="$IMAGE"
else
    echo "[INFO] Digest : ${IMAGE_DIGEST}"
    IMAGE_REF="$IMAGE_DIGEST"
fi

# ──────────────────────────────────────────────
# 4. Signature de l'image
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Signature de l'image en cours..."

export COSIGN_PASSWORD
export COSIGN_INSECURE_SKIP_VERIFY=true

cosign sign \
    --key "$COSIGN_KEY" \
    --tlog-upload=false \
    --insecure-skip-verify \
    --yes \
    "$IMAGE_REF" \
    2>&1

echo ""
echo "[OK] Image signée avec succès."

# ──────────────────────────────────────────────
# 5. Ajout d'annotations de sécurité (SBOM metadata)
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Ajout des annotations de sécurité..."

BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
PIPELINE_ID="${BUILD_NUMBER:-local}"

cosign attest \
    --key "$COSIGN_KEY" \
    --tlog-upload=false \
    --yes \
    --predicate <(cat <<EOF
{
  "buildType": "jenkins-pipeline",
  "builder": "jenkins-master",
  "buildId": "${PIPELINE_ID}",
  "gitCommit": "${GIT_COMMIT}",
  "buildDate": "${BUILD_DATE}",
  "image": "${IMAGE}"
}
EOF
    ) \
    "$IMAGE_REF" \
    2>&1 || echo "[WARN] Attestation optionnelle échouée — la signature reste valide."

echo ""
echo "================================================================"
echo " Signature terminée"
echo "  Image signée : ${IMAGE_REF}"
echo "  Clé utilisée : ${COSIGN_KEY}"
echo "================================================================"

exit 0
