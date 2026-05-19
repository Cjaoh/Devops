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
                echo 'Analyse de sécurité du code...'
                sh 'pip install bandit || true'
                sh 'bandit -r src/ -s B101 || true'
            }
        }

        stage('2. Unit Tests') {
            steps {
                echo 'Exécution des tests...'
                sh 'pip install pytest || true'
                sh 'pytest || true'
            }
        }

        stage('3. Build Docker Image') {
            steps {
                echo 'Construction de l\'image Docker...'
                sh "docker build -t ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG} ."
                sh "docker tag ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG} ${REGISTRY}/${PROJECT}/${IMAGE}:latest"
            }
        }

        stage('4. Push to Harbor') {
            steps {
                echo 'Envoi vers Harbor...'
                sh "echo '${HARBOR_CREDS_PSW}' | docker login ${REGISTRY} -u '${HARBOR_CREDS_USR}' --password-stdin"
                sh "docker push ${REGISTRY}/${PROJECT}/${IMAGE}:${TAG}"
                sh "docker push ${REGISTRY}/${PROJECT}/${IMAGE}:latest"
            }
        }

        stage('5. Deploy Local') {
            steps {
                echo 'Déploiement sur le port 81...'
                sh "IMAGE_TAG=${TAG} docker compose up -d"
            }
        }
    }
}
