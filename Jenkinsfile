pipeline {
    agent any

    environment {
        HARBOR_URL      = "http://localhost" // Passage en HTTP local pour votre démo sans certificats lourds
        HARBOR_REGISTRY = "localhost"        // Cible le registre local
        HARBOR_PROJECT  = "reservation-app"
        IMAGE_NAME      = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/app"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        REPORT_DIR      = "reports"
    }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        // ──────────────────────────────────────────────
        // 1. SAST + Secrets Scan
        // ──────────────────────────────────────────────
        stage('SAST + Secrets Scan') {
            steps {
                echo '=== Analyse statique du code (Bandit + Semgrep) ==='
                sh 'mkdir -p reports'
                sh 'chmod +x ./scripts/*.sh'
                sh './scripts/sast.sh'

                echo '=== Scan des secrets (Gitleaks) ==='
                sh './scripts/secrets_scan.sh'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/bandit-report.json, reports/semgrep-report.json, reports/gitleaks-report.json',
                                     allowEmptyArchive: true
                }
            }
        }

        // ──────────────────────────────────────────────
        // 2. Tests unitaires via docker build
        // ──────────────────────────────────────────────
        stage('Unit Tests') {
            steps {
                echo '=== Exécution des tests unitaires ==='
                sh """
                    mkdir -p reports
                    docker build \
                        -f docker/Dockerfile.test \
                        -t test-runner:${BUILD_NUMBER} \
                        --no-cache \
                        .
                    docker create --name test-extract-${BUILD_NUMBER} test-runner:${BUILD_NUMBER}
                    docker cp test-extract-${BUILD_NUMBER}:/app/reports/coverage.xml reports/coverage.xml || true
                    docker rm  test-extract-${BUILD_NUMBER}
                    docker rmi test-runner:${BUILD_NUMBER} || true
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/coverage.xml',
                                     allowEmptyArchive: true
                }
            }
        }

        // ──────────────────────────────────────────────
        // 3. Build Docker Image
        // ──────────────────────────────────────────────
        stage('Build Docker Image') {
            steps {
                echo "=== Build de l'image Docker ==="
                sh """
                    docker build \
                        --no-cache \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${IMAGE_NAME}:latest \
                        -f docker/Dockerfile .
                """
            }
        }

        // ──────────────────────────────────────────────
        // 4. Dependency & Container Scan
        // ──────────────────────────────────────────────
        stage('Dependency & Container Scan') {
            steps {
                echo '=== OWASP Dependency Check + pip-audit ==='
                sh './scripts/dependency_check.sh'

                echo '=== Scan image avec Trivy ==='
                sh "trivy image --severity HIGH,CRITICAL --format json --output reports/trivy-report.json ${IMAGE_NAME}:${IMAGE_TAG} || true"
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/pip-audit-report.json, reports/trivy-*.json',
                                     allowEmptyArchive: true
                }
            }
        }

        // ──────────────────────────────────────────────
        // 5. Signature de l'image avec Cosign
        // ──────────────────────────────────────────────
        stage('Sign Image') {
            steps {
                echo "=== Signature de l'image avec Cosign ==="
                withCredentials([
                    file(credentialsId: 'cosign-private-key',   variable: 'COSIGN_KEY'),
                    string(credentialsId: 'cosign-password',     variable: 'COSIGN_PASSWORD'),
                    usernamePassword(
                        credentialsId: 'harbor-credentials',
                        usernameVariable: 'HARBOR_USER',
                        passwordVariable: 'HARBOR_PASS'
                    )
                ]) {
                    sh """
                        echo \${HARBOR_PASS} | docker login ${HARBOR_REGISTRY} -u \${HARBOR_USER} --password-stdin
                        ./scripts/sign.sh ${IMAGE_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }

        // ──────────────────────────────────────────────
        // 6. Push vers Harbor
        // ──────────────────────────────────────────────
        stage('Push to Harbor') {
            steps {
                echo '=== Push de l image vers Harbor ==='
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-credentials',
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASS'
                )]) {
                    sh "echo \${HARBOR_PASS} | docker login ${HARBOR_REGISTRY} -u \${HARBOR_USER} --password-stdin"
                    sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${IMAGE_NAME}:latest"
                }
            }
        }

        // ──────────────────────────────────────────────
        // 7. Harbor Policy Check
        // ──────────────────────────────────────────────
        stage('Harbor Policy Check') {
            steps {
                echo '=== Vérification des politiques de sécurité Harbor ==='
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-credentials',
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASS'
                )]) {
                    sh """
                        HARBOR_URL=${HARBOR_URL} \
                        HARBOR_USER=\${HARBOR_USER} \
                        HARBOR_PASS=\${HARBOR_PASS} \
                        HARBOR_CA_CERT=tls/harbor-ca.crt \
                        ./scripts/harbor_check_policy.sh ${IMAGE_NAME}:${IMAGE_TAG}
                    ```
                }
            }
        }

        // ──────────────────────────────────────────────
        // 8. Vérification de la signature Cosign
        // ──────────────────────────────────────────────
        stage('Verify Signature') {
            steps {
                echo "=== Vérification de la signature Cosign ==="
                withCredentials([
                    file(credentialsId: 'cosign-public-key', variable: 'COSIGN_PUB')
                ]) {
                    sh """
                        COSIGN_PUBLIC_KEY=\${COSIGN_PUB} \
                        ./scripts/verify.sh ${IMAGE_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }

        // ──────────────────────────────────────────────
        // 9. Déploiement Local Applicatif Direct
        // ──────────────────────────────────────────────
        stage('Deploy Application Local') {
            steps {
                echo '=== Déploiement via Docker Compose V2 Local (Démonstration) ==='
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-credentials',
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASS'
                )]) {
                    sh """
                        echo \${HARBOR_PASS} | docker login ${HARBOR_REGISTRY} -u \${HARBOR_USER} --password-stdin
                        
                        # Injection des variables d'environnement à la volée pour Compose V2
                        export HARBOR_URL="${HARBOR_REGISTRY}"
                        export IMAGE_TAG="${IMAGE_TAG}"
                        export POSTGRES_PASSWORD="password_de_soutenance_123"
                        export SECRET_KEY="ma_cle_secrete_jwt_generée"
                        
                        # Utilisation stricte de la commande sans tiret
                        docker compose down || true
                        docker compose up -d
                    """
                }
                echo "=== Déploiement local exécuté sur le port 80 ==="
            }
        }
    }

    post {
        always {
            echo '=== Nettoyage : déconnexion Harbor ==='
            sh "docker logout ${HARBOR_REGISTRY} || true"
        }
        success {
            echo "✅ Pipeline validé et déployé avec succès — Démo prête !"
        }
        failure {
            echo "❌ Échec du pipeline — Vérifier l'étape en anomalie."
        }
    }
}
