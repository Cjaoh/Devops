pipeline {
    agent any

    environment {
        REGISTRY = "localhost"
        PROJECT  = "library"
        IMAGE    = "resource-app"
        TAG      = "${BUILD_NUMBER}"
        HARBOR_CREDS = credentials('harbor-creds')
    }

    stages {
        stage('1. Code Security') {
            steps {
                echo 'Analyse de sécurité du code (Simulée pour la démo)...'
                sh 'echo "Bandit scan completed successfully. 0 critical vulnerabilities found."'
            }
        }

        stage('2. Unit Tests') {
            steps {
                echo 'Exécution des tests (Simulée pour la démo)...'
                sh 'echo "Pytest completed. 15 tests passed. Coverage: 85%"'
            }
        }

        stage('3. Téléchargement des outils & Build Image') {
            steps {
                echo 'Récupération de l\'outil Docker...'
                // Télécharge l'exécutable Docker officiel pour que Jenkins puisse s'en servir
                sh '''
                    if [ ! -f ./docker/docker ]; then
                        curl -fsSL https://docker.com -o docker.tgz
                        tar -xzvf docker.tgz
                        rm docker.tgz
                    fi
                '''
                echo 'Construction de l\'image Docker...'
                sh "./docker/docker build -t ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG} ."
                sh "./docker/docker tag ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG} ${REGISTRY}/${PROJECT}/${IMAGE}:latest"
            }
        }

        stage('4. Push to Harbor') {
            steps {
                echo 'Envoi vers Harbor...'
                sh "./docker/docker login ${REGISTRY} -u '${HARBOR_CREDS_USR}' -p '${HARBOR_CREDS_PSW}'"
                sh "./docker/docker push ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG}"
                sh "./docker/docker push ${REGISTRY}/${PROJECT}/${IMAGE}:latest"
            }
        }

        stage('5. Deploy Local') {
            steps {
                echo 'Déploiement sur le port 81...'
                // Téléchargement de docker-compose si manquant
                sh '''
                    if [ ! -f ./docker-compose-bin ]; then
                        curl -SL https://github.com -o ./docker-compose-bin
                        chmod +x ./docker-compose-bin
                    fi
                '''
                sh "IMAGE_TAG=${TAG} ./docker-compose-bin up -d"
            }
        }
    }
}
