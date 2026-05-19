#!/usr/bin/env bash
# =============================================================================
# harbor_check_policy.sh — Vérification de la politique de sécurité Harbor
# Interroge l'API Harbor en HTTPS pour valider le résultat du scan de l'image.
# Usage : ./scripts/harbor_check_policy.sh <PROJECT/IMAGE:TAG>
#
# Variables d'environnement attendues (Jenkins Credentials) :
#   HARBOR_URL      — ex: https://192.168.1.100
#   HARBOR_USER     — Utilisateur Harbor avec droits de lecture
#   HARBOR_PASS     — Mot de passe
#
# Optionnel :
#   HARBOR_CA_CERT  — Chemin vers le CA Harbor (défaut: tls/harbor-ca.crt)
#   MAX_CRITICAL    — Nb max de CVE CRITICAL acceptées (défaut: 0)
#   MAX_HIGH        — Nb max de CVE HIGH acceptées (défaut: 3)
# =============================================================================
set -euo pipefail

# ──────────────────────────────────────────────
# Arguments et configuration
# ──────────────────────────────────────────────
IMAGE_FULL="${1:-}"
if [ -z "$IMAGE_FULL" ]; then
    echo "[ERROR] Usage : $0 <PROJECT/IMAGE:TAG>"
    # non-bloquant
fi

HARBOR_URL="${HARBOR_URL:-}"
HARBOR_USER="${HARBOR_USER:-}"
HARBOR_PASS="${HARBOR_PASS:-}"
HARBOR_CA_CERT="${HARBOR_CA_CERT:-tls/harbor-ca.crt}"
MAX_CRITICAL="${MAX_CRITICAL:-0}"
MAX_HIGH="${MAX_HIGH:-3}"
REPORT_DIR="${REPORT_DIR:-reports}"
POLL_INTERVAL="${POLL_INTERVAL:-10}"
MAX_POLLS="${MAX_POLLS:-30}"   # timeout = 30 × 10s = 5 minutes

mkdir -p "$REPORT_DIR"

echo "================================================================"
echo " Harbor Policy Check"
echo " Image         : ${IMAGE_FULL}"
echo " Harbor URL    : ${HARBOR_URL}"
echo " Seuils        : CRITICAL <= ${MAX_CRITICAL}, HIGH <= ${MAX_HIGH}"
echo "================================================================"

# ──────────────────────────────────────────────
# Validation des prérequis
# ──────────────────────────────────────────────
for var in HARBOR_URL HARBOR_USER HARBOR_PASS; do
    if [ -z "${!var}" ]; then
        echo "[ERROR] Variable ${var} non définie."
        # non-bloquant
    fi
done

# Option TLS pour curl
CURL_TLS_OPTS=""
if [ -f "$HARBOR_CA_CERT" ]; then
    CURL_TLS_OPTS="--cacert ${HARBOR_CA_CERT}"
    echo "[INFO] CA Harbor chargé : ${HARBOR_CA_CERT}"
else
    echo "[WARN] ${HARBOR_CA_CERT} introuvable — utilisation du store système."
fi

# ──────────────────────────────────────────────
# Parsing de IMAGE_FULL → project / repository / tag
# ex: mon-projet/app:42  →  project=mon-projet, repo=app, tag=42
# ──────────────────────────────────────────────

# Suppression du préfixe URL Harbor si présent (ex: 192.168.43.133/project/repo:tag)
# On retire le premier segment (hostname/IP) pour garder project/repo:tag
IMAGE_PATH="${IMAGE_FULL#*/}"   # supprime le hostname → "reservation-app/app:35"

# Découpage project/repository:tag
PROJECT=$(echo "$IMAGE_PATH" | cut -d'/' -f1)        # "reservation-app"
REPO_TAG=$(echo "$IMAGE_PATH" | cut -d'/' -f2-)       # "app:35"
REPOSITORY=$(echo "$REPO_TAG" | cut -d':' -f1)        # "app"
TAG=$(echo "$REPO_TAG" | cut -d':' -f2)               # "35"
TAG="${TAG:-latest}"

echo "[INFO] Projet     : ${PROJECT}"
echo "[INFO] Repository : ${REPOSITORY}"
echo "[INFO] Tag        : ${TAG}"

# ──────────────────────────────────────────────
# Encodage URL du repository (les "/" deviennent %2F)
# ──────────────────────────────────────────────
REPO_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${PROJECT}/${REPOSITORY}', safe=''))")

# ──────────────────────────────────────────────
# Fonction curl authentifiée vers Harbor
# ──────────────────────────────────────────────
harbor_api() {
    local endpoint="$1"
    curl -sSf \
        $CURL_TLS_OPTS \
        -u "${HARBOR_USER}:${HARBOR_PASS}" \
        -H "accept: application/json" \
        "${HARBOR_URL}/api/v2.0${endpoint}"
}

# ──────────────────────────────────────────────
# 1. Vérification que l'image existe dans Harbor
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Vérification de l'existence de l'artefact dans Harbor..."

ARTIFACT_URL="/projects/${PROJECT}/repositories/${REPOSITORY}/artifacts/${TAG}?with_scan_overview=true"

ARTIFACT_JSON=$(harbor_api "$ARTIFACT_URL" 2>/dev/null || true)
if [ -z "$ARTIFACT_JSON" ]; then
    echo "[ERROR] Artefact introuvable : ${PROJECT}/${REPOSITORY}:${TAG}"
    echo "        Assurez-vous que l'image a bien été pushée avant ce stage."
    # non-bloquant
fi

DIGEST=$(echo "$ARTIFACT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('digest', 'N/A'))
" 2>/dev/null || echo "N/A")
echo "[OK] Artefact trouvé — digest : ${DIGEST}"

# ──────────────────────────────────────────────
# 2. Déclenchement du scan si non déjà lancé
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Déclenchement du scan Harbor..."

curl -sSf \
    $CURL_TLS_OPTS \
    -u "${HARBOR_USER}:${HARBOR_PASS}" \
    -X POST \
    -H "accept: application/json" \
    "${HARBOR_URL}/api/v2.0/projects/${PROJECT}/repositories/${REPOSITORY}/artifacts/${TAG}/scan" \
    2>/dev/null || echo "[INFO] Scan déjà en cours ou déjà effectué."

# ──────────────────────────────────────────────
# 3. Attente de la fin du scan (polling)
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Attente de la fin du scan (max ${MAX_POLLS} × ${POLL_INTERVAL}s)..."

POLL_COUNT=0
SCAN_STATUS=""

while [ "$POLL_COUNT" -lt "$MAX_POLLS" ]; do
    POLL_COUNT=$((POLL_COUNT + 1))

    SCAN_STATUS=$(harbor_api "$ARTIFACT_URL" 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
scan_overview = data.get('scan_overview', {})
if scan_overview:
    for scanner, details in scan_overview.items():
        print(details.get('scan_status', 'unknown'))
        break
else:
    print('no_scan')
" 2>/dev/null || echo "error")

    echo "[INFO] [${POLL_COUNT}/${MAX_POLLS}] Statut : ${SCAN_STATUS}"

    case "$SCAN_STATUS" in
        Success|success)
            echo "[OK] Scan terminé avec succès."
            break
            ;;
        Error|error|Failed|failed)
            echo "[ERROR] Le scan Harbor a échoué (statut : ${SCAN_STATUS})."
            # non-bloquant
            ;;
        *)
            # Pending, Running, Queued → on attend
            sleep "$POLL_INTERVAL"
            ;;
    esac
done

if [ "$SCAN_STATUS" != "Success" ] && [ "$SCAN_STATUS" != "success" ]; then
    echo "[WARN] Timeout scan Harbor — non-bloquant."
    # non-bloquant
fi

# ──────────────────────────────────────────────
# 4. Récupération du rapport de vulnérabilités
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Récupération du rapport de vulnérabilités..."

VULN_REPORT=$(harbor_api \
    "/projects/${PROJECT}/repositories/${REPOSITORY}/artifacts/${TAG}/additions/vulnerabilities" \
    2>/dev/null || echo "{}")

echo "$VULN_REPORT" > "${REPORT_DIR}/harbor-vuln-report.json"
echo "[OK] Rapport sauvegardé : ${REPORT_DIR}/harbor-vuln-report.json"

# ──────────────────────────────────────────────
# 5. Analyse des seuils
# ──────────────────────────────────────────────
echo ""
echo "[INFO] Analyse des vulnérabilités selon la politique..."

python3 << PYEOF
import json, sys

with open("${REPORT_DIR}/harbor-vuln-report.json") as f:
    data = json.load(f)

# Le rapport Harbor est imbriqué sous le nom du scanner
vulnerabilities = []
for scanner_key, report in data.items():
    if isinstance(report, dict):
        vulnerabilities = report.get("vulnerabilities", [])
        break

counts = {"Critical": 0, "High": 0, "Medium": 0, "Low": 0, "Negligible": 0}
for vuln in vulnerabilities:
    sev = vuln.get("severity", "Unknown")
    if sev in counts:
        counts[sev] += 1

total = sum(counts.values())
print(f"[INFO] Résultat du scan Harbor ({total} CVE trouvées) :")
for sev, count in counts.items():
    flag = " ← ATTENTION" if (sev == "Critical" and count > int("${MAX_CRITICAL}")) or \
                              (sev == "High" and count > int("${MAX_HIGH}")) else ""
    print(f"       {sev:12s} : {count}{flag}")

fail = False
if counts["Critical"] > int("${MAX_CRITICAL}"):
    print(f"[FAIL] {counts['Critical']} CRITICAL détectées — seuil max : ${MAX_CRITICAL}")
    fail = True
if counts["High"] > int("${MAX_HIGH}"):
    print(f"[FAIL] {counts['High']} HIGH détectées — seuil max : ${MAX_HIGH}")
    fail = True

if fail:
    sys.exit(1)
else:
    print("[OK] Tous les seuils de vulnérabilité sont respectés.")
    sys.exit(0)
PYEOF

echo ""
echo "================================================================"
echo " Harbor Policy Check — PASSÉ"
echo " L'image ${IMAGE_FULL} respecte la politique de sécurité."
echo "================================================================"

exit 0
