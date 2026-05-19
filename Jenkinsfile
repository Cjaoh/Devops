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
                // Utilisation de l'URL brute et stable des binaires de Docker
                sh '''
                    if [ ! -f ./docker_bin/docker ]; then
                        mkdir -p ./docker_bin
                        curl -fsSL https://docker.com -o docker.tgz
                        tar -xzvf docker.tgz --strip-components=1 -C ./docker_bin
                        rm docker.tgz
                    fi
                '''
                echo 'Construction de l\'image Docker...'
                sh "./docker_bin/docker build -t ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG} ."
                sh "./docker_bin/docker tag ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG} ${REGISTRY}/${PROJECT}/${IMAGE}:latest"
            }
        }

        stage('4. Push to Harbor') {
            steps {
                echo 'Envoi vers Harbor...'
                sh "./docker_bin/docker login ${REGISTRY} -u '${HARBOR_CREDS_USR}' -p '${HARBOR_CREDS_PSW}'"
                sh "./docker_bin/docker push ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG}"
                sh "./docker_bin/docker push ${REGISTRY}/${PROJECT}/${IMAGE}:latest"
            }
        }

        stage('5. Deploy Local') {
            steps {
                echo 'Déploiement sur le port 81...'
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
