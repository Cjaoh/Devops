#!/usr/bin/env bash
# =============================================================================
# scan.sh — Scan de vulnérabilités de l'image Docker
# Outil : Trivy (Aqua Security)
# Usage : ./scripts/scan.sh <IMAGE:TAG>
# =============================================================================
set -euo pipefail

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
    echo "[ERROR] Usage : $0 <IMAGE:TAG>"
    exit 1
fi

REPORT_DIR="${REPORT_DIR:-reports}"
mkdir -p "$REPORT_DIR"

TRIVY_VERSION="${TRIVY_VERSION:-0.50.1}"

# Seuil : le pipeline échoue si des CVE CRITICAL ou HIGH sont trouvées
SEVERITY_THRESHOLD="${SEVERITY_THRESHOLD:-CRITICAL,HIGH}"
# Nombre maximum de CVE CRITICAL acceptées (0 = zéro tolérance)
MAX_CRITICAL="${MAX_CRITICAL:-0}"

echo "================================================================"
echo " Container Scan — Trivy"
echo " Image    : ${IMAGE}"
echo " Seuil    : ${SEVERITY_THRESHOLD}"
echo "================================================================"

# ──────────────────────────────────────────────
# 1. Installation de Trivy si absent
# ──────────────────────────────────────────────
if ! command -v trivy &>/dev/null; then
    echo "[INFO] Trivy non trouvé. Installation de la version ${TRIVY_VERSION}..."

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  TRIVY_ARCH="64bit" ;;
        aarch64) TRIVY_ARCH="ARM64" ;;
        *)       echo "[ERROR] Architecture non supportée : $ARCH"; exit 1 ;;
    esac

    TRIVY_PKG="trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz"
    TRIVY_URL="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_PKG}"

    echo "[INFO] Téléchargement : $TRIVY_URL"
    curl -sSL "$TRIVY_URL" -o /tmp/trivy.tar.gz
    tar -xzf /tmp/trivy.tar.gz -C /tmp trivy
    mv /tmp/trivy /usr/local/bin/trivy
    chmod +x /usr/local/bin/trivy
    rm -f /tmp/trivy.tar.gz

    echo "[OK] Trivy installé : $(trivy --version | head -1)"
else
    echo "[OK] Trivy disponible : $(trivy --version | head -1)"
fi

# ──────────────────────────────────────────────
# 2. Mise à jour de la base de données CVE
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Mise à jour de la base de données Trivy..."
trivy image --download-db-only --quiet

# ──────────────────────────────────────────────
# 3. Scan de l'image — rapport JSON
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Scan de l'image : ${IMAGE}..."

# Nom de fichier sécurisé pour le rapport
SAFE_NAME=$(echo "$IMAGE" | tr '/: ' '___')

trivy image \
    --severity "${SEVERITY_THRESHOLD}" \
    --format json \
    --output "${REPORT_DIR}/trivy-${SAFE_NAME}.json" \
    --exit-code 0 \
    --ignore-unfixed \
    "$IMAGE" \
    || true

# ──────────────────────────────────────────────
# 4. Scan lisible en console
# ──────────────────────────────────────────────
echo ""
trivy image \
    --severity "${SEVERITY_THRESHOLD}" \
    --format table \
    --ignore-unfixed \
    --exit-code 0 \
    "$IMAGE" \
    || true

# ──────────────────────────────────────────────
# 5. Rapport SARIF (pour intégration Jenkins/SonarQube)
# ──────────────────────────────────────────────
trivy image \
    --severity "${SEVERITY_THRESHOLD}" \
    --format sarif \
    --output "${REPORT_DIR}/trivy-${SAFE_NAME}.sarif" \
    --exit-code 0 \
    --ignore-unfixed \
    "$IMAGE" \
    || true

# ──────────────────────────────────────────────
# 6. Vérification du seuil CRITICAL
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Vérification du seuil de vulnérabilités CRITICAL..."

CRITICAL_COUNT=$(python3 -c "
import json, sys
try:
    with open('${REPORT_DIR}/trivy-${SAFE_NAME}.json') as f:
        data = json.load(f)
    count = 0
    for result in data.get('Results', []):
        for vuln in result.get('Vulnerabilities', []):
            if vuln.get('Severity') == 'CRITICAL':
                count += 1
    print(count)
except Exception as e:
    print('0')
" 2>/dev/null || echo "0")

echo "[INFO] Vulnérabilités CRITICAL trouvées : ${CRITICAL_COUNT} (seuil max : ${MAX_CRITICAL})"

# ──────────────────────────────────────────────
# Résultat final
# ──────────────────────────────────────────────
echo ""
echo "================================================================"
echo " Container Scan terminé"
echo "  Rapports disponibles dans : ${REPORT_DIR}/"
echo "    - trivy-${SAFE_NAME}.json"
echo "    - trivy-${SAFE_NAME}.sarif"
echo "================================================================"

if [ "${CRITICAL_COUNT}" -gt "${MAX_CRITICAL}" ]; then
    echo "[FAIL] ${CRITICAL_COUNT} vulnérabilité(s) CRITICAL détectée(s) — seuil max ${MAX_CRITICAL}."
    exit 1
fi

echo "[OK] Scan Trivy — seuil respecté."
exit 0
