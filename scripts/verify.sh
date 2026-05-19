#!/usr/bin/env bash
# =============================================================================
# verify.sh — Vérification de la signature Cosign avant déploiement
# Outil : Cosign (Sigstore)
# Usage : ./scripts/verify.sh <IMAGE:TAG>
#
# Variables d'environnement attendues :
#   COSIGN_PUBLIC_KEY — Chemin vers la clé publique (.pub) ou son contenu
# =============================================================================
set -euo pipefail

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
    echo "[ERROR] Usage : $0 <IMAGE:TAG>"
    exit 1
fi

COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-cosign.pub}"

echo "================================================================"
echo " Vérification de signature — Cosign"
echo " Image      : ${IMAGE}"
echo " Clé publique : ${COSIGN_PUBLIC_KEY}"
echo "================================================================"

# ──────────────────────────────────────────────
# 1. Vérification des prérequis
# ──────────────────────────────────────────────
if ! command -v cosign &>/dev/null; then
    echo "[ERROR] Cosign n'est pas installé."
    exit 1
fi

if [ ! -f "$COSIGN_PUBLIC_KEY" ]; then
    echo "[ERROR] Clé publique Cosign introuvable : ${COSIGN_PUBLIC_KEY}"
    exit 1
fi

# ──────────────────────────────────────────────
# 2. Vérification de la signature
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Vérification de la signature cryptographique..."

VERIFY_EXIT=0
cosign verify \
    --key "$COSIGN_PUBLIC_KEY" \
    --insecure-ignore-tlog \
    "$IMAGE" \
    2>&1 \
    || VERIFY_EXIT=$?

if [ "$VERIFY_EXIT" -ne 0 ]; then
    echo ""
    echo "[FAIL] ═══════════════════════════════════════════════"
    echo "[FAIL]  SIGNATURE INVALIDE ou ABSENTE"
    echo "[FAIL]  L'image '${IMAGE}' n'est PAS certifiée."
    echo "[FAIL]  Déploiement BLOQUÉ."
    echo "[FAIL] ═══════════════════════════════════════════════"
    exit 1
fi

# ──────────────────────────────────────────────
# 3. Affichage du certificat / métadonnées
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Détails de la signature :"
cosign verify \
    --key "$COSIGN_PUBLIC_KEY" \
    --insecure-ignore-tlog \
    --output json \
    "$IMAGE" \
    2>/dev/null \
    | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and data:
        sig = data[0]
        payload = sig.get('optional', {})
        print(f\"  Signé par  : {payload.get('subject', 'N/A')}\")
        print(f\"  Build ID   : {payload.get('buildId', 'N/A')}\")
        print(f\"  Git commit : {payload.get('gitCommit', 'N/A')}\")
        print(f\"  Date build : {payload.get('buildDate', 'N/A')}\")
except Exception:
    print('  (métadonnées non disponibles)')
" 2>/dev/null || true

echo ""
echo "================================================================"
echo " Vérification réussie"
echo "  L'image ${IMAGE} est authentique et n'a pas été altérée."
echo "================================================================"

exit 0
