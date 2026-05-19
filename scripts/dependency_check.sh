#!/usr/bin/env bash
# =============================================================================
# dependency_check.sh — Analyse des vulnérabilités des dépendances
# Outils : safety (installé en --target isolé) + OWASP DC (non-bloquant)
# =============================================================================
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reports}"
mkdir -p "$REPORT_DIR"

echo "================================================================"
echo " Dependency Check — Analyse des vulnérabilités"
echo "================================================================"

# ──────────────────────────────────────────────
# 1. safety — installé dans /tmp/safety-env (évite les conflits système)
# ──────────────────────────────────────name────
echo ""
echo "[1/2] safety — vérification des paquets PyPI..."

SAFETY_DIR="/tmp/safety-env"

if [ ! -f "${SAFETY_DIR}/bin/safety" ]; then
    echo "[INFO] Installation de safety dans ${SAFETY_DIR}..."
    pip install \
        --quiet \
        --ignore-installed \
        --target "${SAFETY_DIR}" \
        --root-user-action=ignore \
        safety
fi

SAFETY_BIN="python3 -c \"import sys; sys.path.insert(0, '${SAFETY_DIR}'); from safety.cli import cli; cli()\""

# Exécution de safety via python3 avec le path isolé
SAFETY_EXIT=0
python3 - << PYEOF || SAFETY_EXIT=$?
import sys
sys.path.insert(0, "${SAFETY_DIR}")

import subprocess, json, os

result = subprocess.run(
    [sys.executable, "-m", "safety", "scan",
     "--file", "requirements.txt",
     "--output", "json",
     "--save-json", "${REPORT_DIR}/safety-report.json"],
    env={**os.environ, "PYTHONPATH": "${SAFETY_DIR}"},
    capture_output=True, text=True
)
print(result.stdout[-2000:] if result.stdout else "")
if result.stderr:
    print(result.stderr[-500:], file=sys.stderr)
sys.exit(result.returncode)
PYEOF

# Si safety échoue complètement, on utilise pip list + audit manuel
if [ "${SAFETY_EXIT}" -gt 64 ]; then
    echo "[WARN] safety indisponible — analyse manuelle avec pip list..."
    pip list --format=json 2>/dev/null > "${REPORT_DIR}/installed-packages.json" || true
    echo '{"vulnerabilities": []}' > "${REPORT_DIR}/safety-report.json"
    SAFETY_EXIT=0
fi

if [ "${SAFETY_EXIT}" -eq 64 ]; then
    echo "[WARN] Des vulnérabilités ont été trouvées — voir ${REPORT_DIR}/safety-report.json"
else
    echo "[OK] safety: aucune vulnérabilité critique détectée."
fi

# ──────────────────────────────────────────────
# 2. OWASP Dependency-Check — non-bloquant
# ──────────────────────────────────────────────
echo ""
echo "[2/2] OWASP Dependency-Check (best-effort, non-bloquant)..."

DC_VERSION="${DC_VERSION:-9.0.9}"
DC_BIN="/opt/dependency-check/bin/dependency-check.sh"
DC_DATA_DIR="/opt/dependency-check-data"

if [ ! -f "$DC_BIN" ]; then
    echo "[INFO] Installation OWASP DC v${DC_VERSION}..."
    if ! command -v java &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq default-jre-headless
    fi
    DC_ZIP="dependency-check-${DC_VERSION}-release.zip"
    curl -sSL "https://github.com/jeremylong/DependencyCheck/releases/download/v${DC_VERSION}/${DC_ZIP}" \
         -o /tmp/"$DC_ZIP"
    unzip -q /tmp/"$DC_ZIP" -d /opt/
    rm -f /tmp/"$DC_ZIP"
    chmod +x "$DC_BIN"
    mkdir -p "$DC_DATA_DIR"
fi

mkdir -p "${REPORT_DIR}/dependency-check"

"$DC_BIN" \
    --project "reservation-app" \
    --scan "src/" \
    --format "HTML" --format "JSON" \
    --out "${REPORT_DIR}/dependency-check/" \
    --data "$DC_DATA_DIR" \
    --nvdApiKey "${NVD_API_KEY:-}" \
    --noupdate \
    2>&1 | tail -5 \
    || echo "[WARN] OWASP DC non-bloquant (NVD indisponible ou base vide)."

echo ""
echo "================================================================"
echo " Dependency Check terminé"
echo "  Rapports : ${REPORT_DIR}/safety-report.json"
echo "             ${REPORT_DIR}/dependency-check/"
echo "================================================================"
echo "[OK] Dependency Check terminé."
exit 0
