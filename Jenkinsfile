pipeline {
    agent any

    environment {
        DOCKER_IMAGE          = 'eggta3500/pillmate'
        PROJECT_ID            = 'pillmate-project'
        CLUSTER_NAME          = 'pillmate-cluster'
        LOCATION              = 'asia-northeast3-a'
        DOCKERHUB_CREDENTIALS = 'dockerhub'
        GKE_CREDENTIALS       = 'gke'
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout code') {
            steps {
                checkout scm
            }
        }

        stage('Build image') {
            steps {
                script {
                    app = docker.build("${DOCKER_IMAGE}:${env.BUILD_ID}")
                }
            }
        }

        stage('Test image') {
            steps {
                script {
                    app.inside {
                        sh 'cd /app && node scripts/check-syntax.js'
                    }
                }
            }
        }

        stage('Push image') {
            when {
                anyOf { branch 'develop'; branch 'main' }
            }
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', DOCKERHUB_CREDENTIALS) {
                        app.push("${env.BUILD_ID}")
                        app.push(env.BRANCH_NAME == 'main' ? 'latest' : 'develop')
                    }
                }
            }
        }

        stage('Deploy to GKE') {
            when {
                branch 'main'
            }
            steps {
                sh "sed -i 's#IMAGE_PLACEHOLDER#${DOCKER_IMAGE}:${env.BUILD_ID}#g' k8s/app.yaml"
                step([
                    $class: 'KubernetesEngineBuilder',
                    projectId: env.PROJECT_ID,
                    clusterName: env.CLUSTER_NAME,
                    location: env.LOCATION,
                    manifestPattern: 'k8s/',
                    credentialsId: env.GKE_CREDENTIALS,
                    verifyDeployments: true
                ])
            }
        }
    }

    post {
        always {
            sh "docker rmi ${DOCKER_IMAGE}:${env.BUILD_ID} || true"
        }
    }
}
