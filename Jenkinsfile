pipeline {
    agent any

    environment {
        // Global variables
        DOCKER_REGISTRY = 'docker.io/hemantr1' // e.g., 'docker.io/username'
        IMAGE_NAME_BACKEND = 'ai-attendance-backend'
        IMAGE_NAME_FRONTEND = 'ai-attendance-frontend'
        KUBE_NAMESPACE = 'ai-attendance'
        SCANNER_HOME = tool 'SonarScanner' // Make sure SonarScanner is configured in Jenkins
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Static Analysis & Security') {
            parallel {
                // stage('OWASP Dependency Check') {
                //     steps {
                //         // Requires OWASP Dependency-Check Plugin
                //         dependencyCheck additionalArguments: '--format HTML', odcInstallation: 'DP-Check' 
                //     }
                // }
                // stage('SonarQube Analysis') {
                //     steps {
                //         withSonarQubeEnv('SonarQube') { // 'SonarQube' is the server name in Jenkins config
                //             sh "${SCANNER_HOME}/bin/sonar-scanner \
                //                 -Dsonar.projectKey=ai-attendance \
                //                 -Dsonar.sources=."
                //         }
                //     }
                // }
                stage('Trivy File Scan') {
                    steps {
                         // Assumes Trivy is installed on the agent
                        sh 'trivy fs --exit-code 0 --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL .'
                    }
                }
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                script {
                    // Build Backend
                    // Use empty string registry URL to default to Docker Hub (index.docker.io)
                    docker.withRegistry('', 'docker-credentials-id') {
                        def backendImage = docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME_BACKEND}:${BUILD_NUMBER}", "./backend")
                        backendImage.push()
                        backendImage.push("latest")
                    }

                    // Build Frontend
                    docker.withRegistry('', 'docker-credentials-id') {
                        def frontendImage = docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME_FRONTEND}:${BUILD_NUMBER}", "./frontend")
                        frontendImage.push()
                        frontendImage.push("latest")
                    }
                }
            }
        }

        stage('Image Security Scan (Trivy)') {
            steps {
                // Scan the built images
                sh "trivy image ${DOCKER_REGISTRY}/${IMAGE_NAME_BACKEND}:${BUILD_NUMBER}"
                sh "trivy image ${DOCKER_REGISTRY}/${IMAGE_NAME_FRONTEND}:${BUILD_NUMBER}"
            }
        }

        stage('Deploy to Dev') {
            steps {
                script {
                    // Deploy using Helm
                    // Assumes kubeconfig is set up or using a credentials plugin
                    withKubeConfig([credentialsId: 'kube-config-dev']) {
                        sh """
                            helm upgrade --install ai-attendance-dev ./helm/ai-attendance \
                            -f ./helm/values-dev.yaml \
                            --set backend.image.tag=${BUILD_NUMBER} \
                            --set frontend.image.tag=${BUILD_NUMBER} \
                            --namespace ${KUBE_NAMESPACE}-dev --create-namespace
                        """
                    }
                }
            }
        }

        // stage('Deploy to Test') {
        //     // Triggered manually or after successful Dev deployment
        //     input {
        //         message "Deploy to Test?"
        //         ok "Deploy"
        //     }
        //     steps {
        //         withKubeConfig([credentialsId: 'kube-config-test']) {
        //             sh """
        //                 helm upgrade --install ai-attendance-test ./helm/ai-attendance \
        //                 -f ./helm/values-test.yaml \
        //                 --set backend.image.tag=${BUILD_NUMBER} \
        //                 --set frontend.image.tag=${BUILD_NUMBER} \
        //                 --namespace ${KUBE_NAMESPACE}-test --create-namespace
        //             """
        //         }
        //     }
        // }

        // stage('Deploy to Prod') {
        //      input {
        //         message "Deploy to Production?"
        //         ok "Deploy"
        //     }
        //     steps {
        //         withKubeConfig([credentialsId: 'kube-config-prod']) {
        //             sh """
        //                 helm upgrade --install ai-attendance-prod ./helm/ai-attendance \
        //                 -f ./helm/values-prod.yaml \
        //                 --set backend.image.tag=${BUILD_NUMBER} \
        //                 --set frontend.image.tag=${BUILD_NUMBER} \
        //                 --namespace ${KUBE_NAMESPACE}-prod --create-namespace
        //             """
        //         }
        //     }
        // }
    }
}
