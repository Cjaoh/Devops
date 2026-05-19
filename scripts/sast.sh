#!/usr/bin/env bash
# =============================================================================
# sast.sh — Analyse statique du code source (SAST)
# Outils : Bandit (Python) + Semgrep
# =============================================================================
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reports}"
mkdir -p "$REPORT_DIR"

echo "================================================================"
echo " SAST — Analyse statique de sécurité"
echo "================================================================"

# ──────────────────────────────────────────────
# 1. Bandit — Analyse Python
# ──────────────────────────────────────────────
echo ""
echo "[1/2] Bandit — analyse du code Python..."

if ! command -v bandit &>/dev/null; then
    echo "[INFO] Installation de Bandit..."
    pip install --quiet bandit --break-system-packages
fi

bandit \
    -r src/ \
    -f json \
    -o "${REPORT_DIR}/bandit-report.json" \
    --severity-level medium \
    --confidence-level medium \
    || BANDIT_EXIT=$?

# Rapport lisible en console
bandit \
    -r src/ \
    --severity-level medium \
    --confidence-level medium \
    -f txt \
    || true

BANDIT_EXIT=${BANDIT_EXIT:-0}

if [ "$BANDIT_EXIT" -eq 0 ]; then
    echo "[OK] Bandit — aucune vulnérabilité MEDIUM/HIGH détectée."
elif [ "$BANDIT_EXIT" -eq 1 ]; then
    echo "[WARN] Bandit — des problèmes ont été détectés. Voir ${REPORT_DIR}/bandit-report.json"
else
    echo "[ERROR] Bandit a échoué (exit code: ${BANDIT_EXIT})."
    exit "$BANDIT_EXIT"
fi

# ──────────────────────────────────────────────
# 2. Semgrep — Analyse multi-règles
# ──────────────────────────────────────────────
echo ""
echo "[2/2] Semgrep — analyse avec règles OWASP + Python..."

if ! command -v semgrep &>/dev/null; then
    echo "[INFO] Installation de Semgrep..."
    pip install --quiet --break-system-packages semgrep
fi

semgrep \
    --config "p/python" \
    --config "p/owasp-top-ten" \
    --config "p/secrets" \
    --json \
    --output "${REPORT_DIR}/semgrep-report.json" \
    src/ \
    || SEMGREP_EXIT=$?

SEMGREP_EXIT=${SEMGREP_EXIT:-0}

# Affichage résumé
SEMGREP_FINDINGS=$(python3 -c "
import json, sys
try:
    with open('${REPORT_DIR}/semgrep-report.json') as f:
        data = json.load(f)
    results = data.get('results', [])
    high = sum(1 for r in results if r.get('extra', {}).get('severity') == 'ERROR')
    medium = sum(1 for r in results if r.get('extra', {}).get('severity') == 'WARNING')
    print(f'Findings: {len(results)} total — ERROR: {high}, WARNING: {medium}')
except Exception as e:
    print(f'Impossible de lire le rapport Semgrep: {e}')
" 2>/dev/null || echo "Rapport Semgrep non disponible.")

echo "[INFO] Semgrep — $SEMGREP_FINDINGS"

if [ "$SEMGREP_EXIT" -eq 0 ]; then
    echo "[OK] Semgrep — analyse terminée sans erreur critique."
else
    echo "[WARN] Semgrep a retourné des findings. Voir ${REPORT_DIR}/semgrep-report.json"
fi

# ──────────────────────────────────────────────
# Résumé
# ──────────────────────────────────────────────
echo ""
echo "================================================================"
echo " SAST terminé"
echo "  Rapports disponibles dans : ${REPORT_DIR}/"
echo "    - bandit-report.json"
echo "    - semgrep-report.json"
echo "================================================================"

# Fail du pipeline si Bandit détecte des HIGH
if [ "${BANDIT_EXIT}" -ge 1 ]; then
    echo "[FAIL] Des vulnérabilités ont été détectées par Bandit."
    exit 1
fi

exit 0
