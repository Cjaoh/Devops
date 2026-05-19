#!/usr/bin/env bash
# =============================================================================
# secrets_scan.sh — Détection de secrets dans le code source
# Outil : Gitleaks
# =============================================================================
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reports}"
mkdir -p "$REPORT_DIR"

GITLEAKS_VERSION="${GITLEAKS_VERSION:-8.18.4}"
GITLEAKS_BIN="/usr/local/bin/gitleaks"

echo "================================================================"
echo " Secrets Scan — Détection de secrets avec Gitleaks"
echo "================================================================"

# ──────────────────────────────────────────────
# 1. Installation de Gitleaks si absent
# ──────────────────────────────────────────────
if ! command -v gitleaks &>/dev/null; then
    echo "[INFO] Gitleaks non trouvé. Installation de la version ${GITLEAKS_VERSION}..."

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH_LABEL="x64" ;;
        aarch64) ARCH_LABEL="arm64" ;;
        *)       echo "[ERROR] Architecture non supportée : $ARCH"; exit 1 ;;
    esac

    GITLEAKS_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${ARCH_LABEL}.tar.gz"

    echo "[INFO] Téléchargement : $GITLEAKS_URL"
    curl -sSL "$GITLEAKS_URL" -o /tmp/gitleaks.tar.gz
    tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
    mv /tmp/gitleaks "$GITLEAKS_BIN"
    chmod +x "$GITLEAKS_BIN"
    rm -f /tmp/gitleaks.tar.gz

    echo "[OK] Gitleaks installé : $($GITLEAKS_BIN version)"
else
    echo "[OK] Gitleaks disponible : $(gitleaks version)"
fi

# ──────────────────────────────────────────────
# 2. Scan du dépôt
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Scan du dépôt en cours..."

# Gitleaks v8+ utilise uniquement "detect" (les modes "git" et "dir" sont supprimés)
if [ -d ".git" ]; then
    echo "[INFO] Dépôt Git détecté — scan de l'historique complet."
    DETECT_OPTS="--source . --log-opts HEAD"
else
    echo "[WARN] Pas de dépôt Git — scan des fichiers seulement (no-git)."
    DETECT_OPTS="--source . --no-git"
fi

gitleaks detect \
    $DETECT_OPTS \
    --report-format json \
    --report-path "${REPORT_DIR}/gitleaks-report.json" \
    --exit-code 1 \
    --redact \
    || GITLEAKS_EXIT=$?

GITLEAKS_EXIT=${GITLEAKS_EXIT:-0}

# ──────────────────────────────────────────────
# 3. Analyse du rapport
# ──────────────────────────────────────────────
if [ -f "${REPORT_DIR}/gitleaks-report.json" ]; then
    FINDINGS=$(python3 -c "
import json
try:
    with open('${REPORT_DIR}/gitleaks-report.json') as f:
        data = json.load(f)
    count = len(data) if isinstance(data, list) else 0
    if count > 0:
        print(f'{count} secret(s) détecté(s) :')
        for item in data[:5]:  # Affiche les 5 premiers
            rule = item.get('RuleID', 'N/A')
            file = item.get('File', 'N/A')
            line = item.get('StartLine', '?')
            print(f'  - [{rule}] {file}:{line}')
        if count > 5:
            print(f'  ... et {count - 5} autre(s). Voir le rapport complet.')
    else:
        print('Aucun secret détecté.')
except Exception as e:
    print(f'Impossible de lire le rapport : {e}')
" 2>/dev/null || echo "Rapport non lisible.")
    echo "[INFO] $FINDINGS"
fi

# ──────────────────────────────────────────────
# Résultat final
# ──────────────────────────────────────────────
echo ""
echo "================================================================"
echo " Secrets Scan terminé"
echo "  Rapport : ${REPORT_DIR}/gitleaks-report.json"
echo "================================================================"

if [ "${GITLEAKS_EXIT}" -ne 0 ]; then
    echo "[FAIL] Des secrets ont été détectés dans le code source !"
    echo "       Révoquez immédiatement les secrets exposés avant de continuer."
    exit 1
fi

echo "[OK] Aucun secret détecté."
exit 0
